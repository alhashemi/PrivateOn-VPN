package vpn_retry;

#
# PrivateOn-VPN -- Because privacy matters.
#
# Copyright (C) 2014-2015  PrivateOn / Tietosuojakone Oy, Helsinki, Finland
# All rights reserved. Use is subject to license terms.
#


use strict;
use warnings;

use File::stat;

use AnyEvent;
use AnyEvent::Log;

use constant {
	LOG_FILE      => "/var/log/PrivateOn.log",
	INI_FILE      => "/etc/PrivateOn/vpn-default.ini",
	VERSION       => "0.9",
	DEBUG         => 2
};

use constant {
	NET_UNPROTECTED => 0,
	NET_PROTECTED   => 1,
	NET_OFFLINE     => 2,
	NET_CRIPPLED    => 3,
	NET_BROKEN      => 4,
	NET_UNCONFIRMED => 5,
	NET_ERROR       => 99,
	NET_UNKNOWN     => 100
};


sub quick_net_status
{
	my $ctx = shift;
	my $net_status = NET_UNKNOWN;
	my $sys_virtual_path = "/sys/devices/virtual/net/";
	my $sys_net_path = "/sys/class/net/";
	my @net_dir_array = ();
	my $net;

	unless (opendir $net, $sys_virtual_path) {
		$ctx->log(error => "Could not open directory: " . $sys_virtual_path . " Reason: " . $! ." (vpn_retry child)");
		return NET_BROKEN;
	}
	while (my $file = readdir($net)) {
		return NET_PROTECTED if ($file =~ /^tun[0-9]+/);
	}

	unless (opendir $net, $sys_net_path) {
		$ctx->log(error => "Could not open directory: " . $sys_net_path . " Reason: " . $! ." (vpn_retry child)");
		return NET_BROKEN;
	}
	while (my $file = readdir($net)) {
		next unless (-d $sys_net_path."/".$file);
		push @net_dir_array, $sys_net_path."/".$file;
	}
	closedir $net;

	foreach my $dir (@net_dir_array) {
		next unless (-e $dir."/address");
		open my $address, "$dir/address";
		my @lines = <$address>;
		close $address;
		next if ($lines[0] =~ /00\:00\:00\:00\:00\:00/);
		next unless ($lines[0]);

		next unless (-e $dir."/operstate");
		open my $operstate, "$dir/operstate";
		my @line = <$operstate>;
		close $operstate;
		next if ($line[0] =~ /^unknown/);
		if ($line[0] =~ /^down/) {
			$net_status = NET_OFFLINE;
			next;
		}
		return NET_UNPROTECTED if ($line[0] =~ /^up/);
	}
	return $net_status;
}


sub activate_vpn
{
	my $ctx = shift;
	$ctx->log(debug => "Activating VPN connection (vpn_retry child)") if DEBUG > 0;

	# use hardcoded default if vpn-default.ini missing, unreadable or doesn't contain 'id'-key
	my $hardcoded_default_id = 'vpn-de1-nordvpn-udp';

	my $id = "";
	my $vpn_ini;
	unless (open $vpn_ini, INI_FILE) {
		$ctx->log(error => "Could not open '" . INI_FILE . "'  Reason: " . $! ." (vpn_retry child)");
		$ctx->log(error => "Activating failure-mode VPN (vpn_retry child)");
		return system("/usr/bin/nmcli conn up id " . $hardcoded_default_id . " >/dev/null 2&1");
	}
	while (my $line = <$vpn_ini>) {
		if ($line =~/^id=(\S+)/) {
			$id = $1;
			last;
		}
	}
	close $vpn_ini;
	if ($id eq '') { $id = $hardcoded_default_id; };
	return system("/usr/bin/nmcli conn up id $id >/dev/null 2&1");
}


sub retry_vpn
{
	my $ctx = shift;
	$ctx->log(info => "Retrying VPN connection (vpn_retry child)" );

	# wait for log updates to stop
	my $filename = '/var/log/NetworkManager';
	my ($mtime, $log_time);

	# create logfile if it doesn't exist
	if (!(-e $filename)) {
		my $fh;
		unless (open $fh, '>>', $filename) {
			$ctx->log(error => "Could not create " . $filename . ": " . $! ." (vpn_retry child)");
			system("/usr/bin/rm -f /etc/NetworkManager/dispatcher.d/vpn-up");
			system("/bin/pkill -9 openvpn");
			system("/sbin/service network restart");
			sleep 10;
			return activate_vpn($ctx);
		}
		close $fh;
	}

	$mtime = stat($filename)->mtime;
	for (my $i = 0; $i < 3; $i ++) {
		$log_time = stat($filename)->mtime;
		if ($log_time != $mtime) {
			last;
		} else {
			if (quick_net_status($ctx) == NET_PROTECTED) { return 0; }
			sleep 10;
		}
	}
	if (quick_net_status($ctx) == NET_PROTECTED) { return 0; }

	# clear network and restart VPN
	system("/usr/bin/rm -f /etc/NetworkManager/dispatcher.d/vpn-up");
	system("/bin/pkill -9 openvpn");
	system("service network restart");
	sleep 5;

	if (quick_net_status($ctx) == NET_PROTECTED) { return 0; } # just in case

	# wait for log updates to stop
	$mtime = stat($filename)->mtime;
	for (my $i = 0; $i < 4; $i ++) {
		$log_time = stat($filename)->mtime;
		if ($log_time != $mtime) {
			last;
		} else {
			sleep 5;
		}
	}

	return activate_vpn($ctx);
}

 
sub run 
{
	my ($done) = @_;

	my $ctx = new AnyEvent::Log::Ctx;
	$ctx->log_to_file(LOG_FILE);
	$ctx->log(debug => "Child process started (vpn_retry child)") if DEBUG > 0;

	my $result = retry_vpn($ctx);

	$ctx->log(debug => "Child process ended (vpn_retry child)") if DEBUG > 0;
	$done->($result);
	return $result;
}


1;
