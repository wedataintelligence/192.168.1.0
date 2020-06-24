# -*- rpm-spec -*-
# $Id: gsm-tools.spec,v 1.2 2002/10/17 17:54:48 grigory Exp $

Name: gsm-tools
Version: 0.0.3
Release: alt1

Summary: gsm-tools - Tcl/Tk tools for work with GSM phones
License: GPL
Group: Communications
URL: http://gsm-tools.sourceforge.net/

BuildArch: noarch
Source0: %name-%version.tar.bz2

Requires: bwidget tk >= 8.4.0-alt1
BuildRequires: rpm-build >= 4.0.4-alt0.7

%description
Main functions:
    Sending/recieving SMS
    Working with phone book
    Make calls, answer and busy

%prep
%setup -q -n %name

%build

%install 
%__mkdir -p %buildroot{%_tcldatadir/%name/,%_bindir}
%__install -m 0755 %name.tcl %buildroot%_bindir/%name
%__install -m 0644 *.tcl %buildroot%_tcldatadir/%name/
%__rm -f %buildroot%_tcldatadir/%name/%name.tcl

%files
%doc COPYING README TODO VERSION
%_bindir/*
%_tcldatadir/%{name}*

%changelog
* Thu Oct 17 2002 Grigory Milev <week@altlinux.ru> 0.0.3-alt1
- initial release
