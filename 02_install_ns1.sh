#!/bin/bash
# yum -y install epel-release
yum -y install bind bind-utils #haveged
# yum -y install rng-tools
# cat /dev/random | rngtest -c 1000
# systemctl enable haveged
# COPY NS CONFIGURATION FILES
mkdir -p /etc
mkdir -p /var
mkdir -p /var/named
mkdir -p /usr
mkdir -p /usr/local
mkdir -p /usr/local/sbin
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
	type master;
	file "example.com.signed";
};
*/

PASTECONFIGURATIONFILE
cat > /var/named/example.com << PASTECONFIGURATIONFILE
\$ORIGIN example.com
\$TTL 1d
@ IN SOA need.to.know.only. info.example.com. (
	2019011301 ; serial
	1d ; refresh
	1h ; retry
	4w ; expire
	1d ; nx ttl
)

@	IN NS ns1.example.com.
@	IN NS ns2.example.com.
ns1	IN A 1.1.1.1
ns2	IN A 2.2.2.2

@	IN CAA 128 issue "letsencrypt.org"

@	IN MX 1 mx.example.com.
@	IN TXT "v=spf1 mx include:mx.example.com -all"

@	IN A 3.3.3.3

PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-dnssec_setup << PASTECONFIGURATIONFILE
#!/bin/bash
if [ \$# -eq 0 ]; then
	echo "Setup DNSSEC for a zone"
	echo
	echo "usage: \${0} zone"
	echo
	exit 1
fi
zone="\${1}"
cd /var/named/
dnssec-keygen -r /dev/urandom -a NSEC3RSASHA1 -b 2048 -n ZONE \${zone}
dnssec-keygen -r /dev/urandom -f KSK -a NSEC3RSASHA1 -b 4096 -n ZONE \${zone}
echo "*********************************************"
echo "* The following goes into your parent zone: *"
echo "*********************************************"
cat "dsset-\${zone}."

PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-dnssec_sign << PASTECONFIGURATIONFILE
#!/bin/bash
if [ \$# -eq 0 ]; then
	echo "DNSSEC sign a zone"
	echo
	echo "usage: \${0} zone"
	echo
	exit 1
fi
zone="\${1}"
cd /var/named/
dnssec-signzone -t -S -A -3 \$(head -c 1000 /dev/urandom | sha1sum | cut -b 1-16) -o "\${zone}" "\${zone}"
echo "*********************************************"
echo "* The following goes into your parent zone: *"
echo "*********************************************"
cat "dsset-\${zone}."

PASTECONFIGURATIONFILE
# COPY NS CONFIGURATION FILES
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
systemctl start named
systemctl enable named
systemctl status named # check status [optional]
