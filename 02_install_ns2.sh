#!/bin/bash
# yum -y install epel-release
yum -y install bind bind-utils #haveged
# yum -y install rng-tools
# cat /dev/random | rngtest -c 1000
# systemctl enable haveged
# COPY CONFIGURATION FILES
mkdir -p /etc
cat > /etc/named.conf << PASTECONFIGURATIONFILE
options {
	version none;
	listen-on port 53 { any; };
	directory         "/var/named";
	allow-query       { any; };
	allow-update      { none; }; # ip of ns1
	allow-notify      { none; }; # ip of ns1
	notify yes;
	allow-transfer    { none; }; # ip of ns2
	allow-query-cache { localhost; };
	allow-recursion   { localhost; };
	recursion yes;
	auth-nxdomain yes;
	rate-limit {
		all-per-second 20;
		errors-per-second 5;
		exempt-clients { localhost; };
		log-only no;
		nodata-per-second 5;
		nxdomains-per-second 5;
		qps-scale 250;
		referrals-per-second 5;
		responses-per-second 5;
		slip 2;
		window 15;
	};

	dnssec-enable yes;
	dnssec-validation yes;
	dnssec-lookaside auto;

};


zone "." IN {
	type hint;
	file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

/*
zone "example.com" IN {
	type slave;
	masters {91.134.143.137; }; # ip of ns1
	file "example.com.signed";
};
*/

PASTECONFIGURATIONFILE
# COPY CONFIGURATION FILES
chown named:named -R /var/named
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
systemctl start named
systemctl enable named
systemctl status named # check status [optional]
