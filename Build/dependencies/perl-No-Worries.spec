#
# spec file for package perl-No-Worries
#
# Copyright (c) 2015 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           perl-No-Worries
Version:        1.2
Release:        0
%define cpan_name No-Worries
Summary:        No::Worries Perl module
License:        CHECK(GPL-1.0+ or Artistic-1.0)
Group:          Development/Libraries/Perl
Url:            http://search.cpan.org/dist/No-Worries/
#Source:        http://www.cpan.org/authors/id/L/LC/LCONS/No-Worries-%{version}.tar.gz
Source:         No-Worries-%{version}.tar.gz
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  perl
BuildRequires:  perl-macros
BuildRequires:  perl-URI
BuildRequires:  perl-HTTP-Date
BuildRequires:  perl-Params-Validate
Requires:       perl
Requires:       perl-URI
Requires:       perl-HTTP-Date
Requires:       perl-Params-Validate
%{perl_requires}

%description
No::Worries Perl module

%prep
%setup -q -n No-Worries-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
%{__make} %{?_smp_mflags}

%check
%{__make} test

%install
%perl_make_install
%perl_process_packlist
%perl_gen_filelist

%files -f %{name}.files
%defattr(-,root,root,755)

%changelog
