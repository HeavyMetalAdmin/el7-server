#!/bin/bash
yum -y install epel-release
yum -y install postfix dovecot postfix-pcre opendkim
rm -rf /etc/dovecot/conf.d

# COPY CONFIGURATION FILES
mkdir -p /usr
mkdir -p /usr/local
mkdir -p /usr/local/sbin
mkdir -p /etc
mkdir -p /etc/dovecot
mkdir -p /etc/postfix
mkdir -p /etc/logrotate.d
mkdir -p /etc/opendkim
mkdir -p /etc/opendkim/keys
mkdir -p /etc/opendkim/keys/example.com
cat > /usr/local/sbin/el7-mx_add_user << PASTECONFIGURATIONFILE
#!/bin/sh

if [ ! \$# = 1 ];  then
	echo "Usage: \${0} username@domain"
	exit 1
fi
username=\$(echo "\${1}" | cut -f1 -d "@")
domain=\$(echo "\${1}" | cut -s -f2 -d "@")
if [ -z "\$domain" ] || [ -z "\$username" ]; then
	echo "No domain and/or username given."
	echo "Usage: \${0} username@domain"
	exit 2
fi

echo "Adding domain to /etc/postfix/vhosts"
echo "\${domain}" >> /etc/postfix/vhosts
sort -u /etc/postfix/vhosts -o /etc/postfix/vhosts # remove dups

echo "Adding user \$username@\$domain to /etc/dovecot/users"
echo "\$username@\$domain::5000:5000::/home/vmail/\$domain/\$username/:/bin/false::" >> /etc/dovecot/users
sort -u /etc/dovecot/users -o /etc/dovecot/users # remove dups

echo "Creating user directory /home/vmail/\$domain/\$username/"
mkdir -p /home/vmail/\$domain/\$username/
chown -R 5000:5000 /home/vmail
chmod 700 /home/vmail/\$domain

echo "Adding user to /etc/postfix/vmaps"
echo "\${1}  \$domain/\$username/" >> /etc/postfix/vmaps
sort -u /etc/postfix/vmaps -o /etc/postfix/vmaps # remove dups
postmap /etc/postfix/vmaps
postfix reload

if [ -n "\$(cat /etc/dovecot/passwd | grep "\$username@\$domain:")" ]; then
	echo "A password already exists for \$username@\$domain"
	read -n1 -p "Update password? [Y/N]? " UPDATE
	case \$UPDATE in
		y | Y)
			echo "Deleting old password from /etc/dovecot/passwd"
			tmp=\$(mktemp)
			grep -v "\$username@\$domain:" /etc/dovecot/passwd > \$tmp
			mv \$tmp /etc/dovecot/passwd
			;;
		*)
			echo "Keeping current password for \$username@\$domain in /etc/dovecot/passwd"
			systemctl reload dovecot
			exit 0
			;;
	esac
fi	
echo "Create a password for the new email user"
passwd=\`doveadm pw -u \$username\`
echo "Adding password for \$username@\$domain to /etc/dovecot/passwd"
touch /etc/dovecot/passwd
echo  "\$username@\$domain:\$passwd" >> /etc/dovecot/passwd
chmod 640 /etc/dovecot/passwd
chown dovecot:dovecot /etc/dovecot/passwd

systemctl reload dovecot

PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-mx_delete_user << PASTECONFIGURATIONFILE
#!/bin/bash
#
# deldovecotuser - for deleting virtual dovecot users
#
if [ ! \$# = 1 ]
 then
  echo -e "Usage: \$0 username@domain"
  exit 1
 else
  user=\`echo "\$1" | cut -f1 -d "@"\`
  domain=\`echo "\$1" | cut -s -f2 -d "@"\`
  if [ -z "\$domain" ]
   then
    echo -e "No domain given\\nUsage: \$0 username@domain: "
    exit 2
  fi
fi
read -n 1 -p "Delete user \$user@\$domain from dovecot? [Y/N]? "
echo
case \$REPLY in
 y | Y)
  new_users=\`grep -v \$user@\$domain /etc/dovecot/users\`
  new_passwd=\`grep -v \$user@\$domain /etc/dovecot/passwd\`
  new_vmaps=\`grep -v \$user@\$domain /etc/postfix/vmaps\`
  echo "Deleting \$user@\$domain from /etc/dovecot/users"
  echo "\$new_users" > /etc/dovecot/users
  echo "Deleting \$user@\$domain from /etc/dovecot/passwd"
  echo "\$new_passwd" > /etc/dovecot/passwd
  echo "Deleting \$user@\$domain from /etc/postfix/vmaps"
  echo "\$new_vmaps" > /etc/postfix/vmaps
  postmap /etc/postfix/vmaps
  postfix reload
  read -n1 -p "Delete all files in /home/vmail/\$domain/\$user? [Y/N]? " DELETE
  echo
  case \$DELETE in
   y | Y)
    echo "Deleting files in /home/vmail/\$domain/\$user"
    rm -fr /home/vmail/\$domain/\$user
    rmdir --ignore-fail-on-non-empty /home/vmail/\$domain
   ;;
   * )
    echo "Not deleting files in /home/vmail/\$domain/\$user"
   ;;
  esac
 ;;
 * )
  echo "Aborting..."
 ;;
esac
PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-mx_dkim << PASTECONFIGURATIONFILE
#!/bin/sh

if [ ! \$# = 1 ];  then
	echo "Add DKIM key for domain"
	echo "Usage: \${0} <domain>"
	exit 1
fi
domain="\${1}"
selector=\$(date +%Y%m%dT%H%M%S)
mkdir -p /etc/opendkim/keys/\${domain}
opendkim-genkey -b 2048 -d \${domain} -s \${selector} -a -D /etc/opendkim/keys/\${domain}/
chown opendkim:opendkim -R /etc/opendkim/keys
echo
echo "Put the following DKIM key into your zone file:"
cat /etc/opendkim/keys/\${domain}/\${selector}.txt
echo
echo "/etc/opendkim/KeyTable"
echo "\${selector}._domainkey.\${domain} \${domain}:\${selector}:/etc/opendkim/keys/\${domain}/\${selector}.private"
echo "/etc/opendkim/SigningTable"
echo "*@\${domain} \${selector}._domainkey.\${domain}"
echo
PASTECONFIGURATIONFILE
cat > /etc/dovecot/users << PASTECONFIGURATIONFILE
info@example.com::5000:5000::/home/vmail/example.com/info/:/bin/false::
PASTECONFIGURATIONFILE
cat > /etc/dovecot/dovecot.conf << PASTECONFIGURATIONFILE
base_dir = /var/run/dovecot/
info_log_path = /var/log/dovecot.info
log_path = /var/log/dovecot
log_timestamp = "%Y-%m-%d %H:%M:%S "

mail_location = maildir:/home/vmail/%d/%n

protocols = pop3

passdb {
	driver = passwd-file
	args = /etc/dovecot/passwd
}
userdb {
	driver = passwd-file
	args = /etc/dovecot/users
	default_fields = uid=vmail gid=vmail home=/home/vmail/%u
}

service auth {


	executable = /usr/libexec/dovecot/auth

	unix_listener /var/spool/postfix/private/auth {
		mode = 0660
		user = postfix
		group = postfix 
	}

}

# we force ssl, see below
auth_mechanisms = plain login CRAM-MD5

service pop3-login {
	inet_listener pop3 {
		port = 0
	}
	inet_listener pop3s {
		port = 995
		ssl = yes
	}

	chroot = login
	executable = /usr/libexec/dovecot/pop3-login
	user = dovecot
	group = dovenull
}

service pop3 {
	executable = /usr/libexec/dovecot/pop3
}

ssl=required
verbose_ssl = yes

local_name mx.example.com {
	ssl_cert=</etc/letsencrypt/live/mx.example.com/fullchain.pem
	ssl_key=</etc/letsencrypt/live/mx.example.com/privkey.pem
}

ssl_protocols = !SSLv2 !SSLv3 !TLSv1 !TLSv1.1
ssl_cipher_list = AES128+EECDH:AES128+EDH:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!SHA1
ssl_prefer_server_ciphers = yes
ssl_dh_parameters_length = 2048

#valid_chroot_dirs = /var/spool/vmail
#protocol pop3 {
#  pop3_uidl_format = %08Xu%08Xv
#}



PASTECONFIGURATIONFILE
cat > /etc/dovecot/passwd << PASTECONFIGURATIONFILE
info@example.com:{CRAM-MD5}e02d374fde0dc75a17a557039a3a5338c7743304777dccd376f332bee68d2cf6
PASTECONFIGURATIONFILE
cat > /etc/postfix/main.cf << PASTECONFIGURATIONFILE
smtpd_banner = \$myhostname ESMTP
biff = no

# stuff
myhostname = mx.example.com
myorigin = \$myhostname
#mydestination = mx.example.com, example.com, localhost, localhost.localdomain
relayhost =
mynetworks = 127.0.0.0/8
mailbox_size_limit = 0
home_mailbox = Maildir/

virtual_mailbox_domains = /etc/postfix/vhosts
virtual_mailbox_base = /home/vmail
virtual_mailbox_maps = hash:/etc/postfix/vmaps
virtual_minimum_uid = 1000
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000

recipient_delimiter = +
inet_interfaces = all

# prevent leaking valid e-mail addresses
disable_vrfy_command = yes
strict_rfc821_envelopes = yes

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

# try delivery for 1h
bounce_queue_lifetime = 1h
maximal_queue_lifetime = 1h

# incoming
smtpd_tls_cert_file = /etc/letsencrypt/live/mx.example.com/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/mx.example.com/privkey.pem
smtpd_tls_security_level = may
smtpd_tls_received_header = yes
smtpd_tls_CAfile = /etc/ssl/certs/ca-bundle.trust.crt
smtpd_tls_CApath = /etc/ssl/certs
smtpd_tls_loglevel = 1
smtpd_hard_error_limit = 1
smtpd_helo_required     = yes
smtpd_error_sleep_time = 0
smtpd_tls_auth_only = yes
smtpd_tls_mandatory_ciphers=high
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3
smtpd_tls_exclude_ciphers=eNULL:aNULL:LOW:MEDIUM:DES:3DES:RC4:MD5:RSA:SHA1
smtpd_tls_dh1024_param_file = \${config_directory}/dhparams.pem
smtpd_delay_reject = yes
smtpd_relay_restrictions =
	permit_mynetworks,
	permit_sasl_authenticated,
	defer_unauth_destination
smtpd_client_restrictions =
	permit_mynetworks,
	permit_sasl_authenticated,
	check_sender_access hash:/etc/postfix/check_sender_access,
	reject_rbl_client zen.spamhaus.org
smtpd_helo_restrictions =
	permit_mynetworks,
	permit_sasl_authenticated,
	reject_invalid_helo_hostname,
	reject_non_fqdn_helo_hostname,
	reject_unknown_helo_hostname,
	permit
smtpd_sender_restrictions =
	permit_mynetworks,
	permit_sasl_authenticated,
# move check_sender_access to smtpd_client_restrictions to whitelist also from rbl
#	check_sender_access hash:/etc/postfix/check_sender_access,
	reject_non_fqdn_sender,
	reject_unknown_sender_domain,
	reject_unlisted_sender,
	permit
smtpd_recipient_restrictions =
	permit_mynetworks,
	permit_sasl_authenticated,
	check_recipient_access hash:/etc/postfix/check_recipient_access
	reject_invalid_hostname,
	reject_non_fqdn_hostname,
	reject_non_fqdn_sender,
	reject_non_fqdn_recipient,
	reject_unknown_sender_domain,
	reject_unknown_recipient_domain,
	reject_unauth_destination,
	reject_unknown_sender_domain,
	permit

# SASL
# if you really want noplaintext you need to remove plain and login in /etc/dovecot/dovecot.conf auth_mechansims
# smtpd_sasl_security_options=noplaintext,noanonymous
# we only prevent anonymous logins
smtpd_sasl_security_options=noanonymous
smtpd_sasl_auth_enable = yes
broken_sasl_auth_clients = no
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_authenticated_header = no
#queue_directory = /var/spool/postfix


# outgoing
smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.trust.crt
smtp_tls_CApath = /etc/ssl/certs
smtp_tls_loglevel = 1
smtp_tls_mandatory_ciphers=high
smtp_tls_mandatory_protocols = !SSLv2, !SSLv3
# Unfortunately too many people don't know how to do SSL correctly
#smtp_tls_security_level = verify
# hence we don't verify :(
smtp_tls_security_level = encrypt
# clean private stuff from headers
#smtp_mime_header_checks = regexp:/etc/postfix/smtp_mime_header_checks
smtp_header_checks = regexp:/etc/postfix/smtp_header_checks

# Slowing down SMTP clients that make many errors
smtpd_error_sleep_time = 1s
smtpd_soft_error_limit = 5
smtpd_hard_error_limit = 10
smtpd_junk_command_limit = 3
# Measures against clients that make too many connections
anvil_rate_time_unit = 60s
smtpd_client_connection_count_limit = 3
smtpd_client_connection_rate_limit = 6
smtpd_client_message_rate_limit = 10
# we only have around 3 legit recipients
smtpd_client_recipient_rate_limit = 5
# prevent brute forcing
# only available in postfix > 3.1
#smtpd_client_auth_rate_limit = 6
smtpd_client_event_limit_exceptions = \$mynetworks

# TODO: SPF
# TODO: DKIM
# TODO: DMARC

alias_maps = hash:/etc/aliases
PASTECONFIGURATIONFILE
cat > /etc/postfix/vhosts << PASTECONFIGURATIONFILE
example.com
PASTECONFIGURATIONFILE
cat > /etc/postfix/master.cf << PASTECONFIGURATIONFILE
#
# Postfix master process configuration file.  For details on the format
# of the file, see the master(5) manual page (command: "man 5 master").
#
# Do not forget to execute "postfix reload" after editing this file.
#
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (yes)   (never) (100)
# ==========================================================================
smtp      inet  n       -       n       -       -       smtpd
#smtp      inet  n       -       n       -       1       postscreen
#smtpd     pass  -       -       n       -       -       smtpd
#dnsblog   unix  -       -       n       -       0       dnsblog
#tlsproxy  unix  -       -       n       -       0       tlsproxy
#submission inet n       -       n       -       -       smtpd
#  -o syslog_name=postfix/submission
#  -o smtpd_tls_security_level=encrypt
#  -o smtpd_sasl_auth_enable=yes
#  -o smtpd_sasl_type=dovecot
#  -o smtpd_sasl_path=private/auth
#  -o smtpd_sasl_security_options=noanonymous
#  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
#  -o smtpd_sender_login_maps=hash:/etc/postfix/virtual
#  -o smtpd_sender_restrictions=reject_sender_login_mismatch
#  -o smtpd_recipient_restrictions=reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_sasl_authenticated,reject
#  -o milter_macro_daemon_name=ORIGINATING
smtps     inet  n       -       n       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
#  -o smtpd_client_restrictions=\$mua_client_restrictions
#  -o smtpd_helo_restrictions=\$mua_helo_restrictions
#  -o smtpd_sender_restrictions=\$mua_sender_restrictions
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
#628       inet  n       -       n       -       -       qmqpd
pickup    unix  n       -       n       60      1       pickup
cleanup   unix  n       -       n       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
#qmgr     unix  n       -       n       300     1       oqmgr
tlsmgr    unix  -       -       n       1000?   1       tlsmgr
rewrite   unix  -       -       n       -       -       trivial-rewrite
bounce    unix  -       -       n       -       0       bounce
defer     unix  -       -       n       -       0       bounce
trace     unix  -       -       n       -       0       bounce
verify    unix  -       -       n       -       1       verify
flush     unix  n       -       n       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       n       -       -       smtp
relay     unix  -       -       n       -       -       smtp
#       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
showq     unix  n       -       n       -       -       showq
error     unix  -       -       n       -       -       error
retry     unix  -       -       n       -       -       error
discard   unix  -       -       n       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       n       -       -       lmtp
anvil     unix  -       -       n       -       1       anvil
scache    unix  -       -       n       -       1       scache
#
# ====================================================================
# Interfaces to non-Postfix software. Be sure to examine the manual
# pages of the non-Postfix software to find out what options it wants.
#
# Many of the following services use the Postfix pipe(8) delivery
# agent.  See the pipe(8) man page for information about \${recipient}
# and other message envelope options.
# ====================================================================
#
# maildrop. See the Postfix MAILDROP_README file for details.
# Also specify in main.cf: maildrop_destination_recipient_limit=1
#
#maildrop  unix  -       n       n       -       -       pipe
#  flags=DRhu user=vmail argv=/usr/local/bin/maildrop -d \${recipient}
#
# ====================================================================
#
# Recent Cyrus versions can use the existing "lmtp" master.cf entry.
#
# Specify in cyrus.conf:
#   lmtp    cmd="lmtpd -a" listen="localhost:lmtp" proto=tcp4
#
# Specify in main.cf one or more of the following:
#  mailbox_transport = lmtp:inet:localhost
#  virtual_transport = lmtp:inet:localhost
#
# ====================================================================
#
# Cyrus 2.1.5 (Amos Gouaux)
# Also specify in main.cf: cyrus_destination_recipient_limit=1
#
#cyrus     unix  -       n       n       -       -       pipe
#  user=cyrus argv=/usr/lib/cyrus-imapd/deliver -e -r \${sender} -m \${extension} \${user}
#
# ====================================================================
#
# Old example of delivery via Cyrus.
#
#old-cyrus unix  -       n       n       -       -       pipe
#  flags=R user=cyrus argv=/usr/lib/cyrus-imapd/deliver -e -m \${extension} \${user}
#
# ====================================================================
#
# See the Postfix UUCP_README file for configuration details.
#
#uucp      unix  -       n       n       -       -       pipe
#  flags=Fqhu user=uucp argv=uux -r -n -z -a\$sender - \$nexthop!rmail (\$recipient)
#
# ====================================================================
#
# Other external delivery methods.
#
#ifmail    unix  -       n       n       -       -       pipe
#  flags=F user=ftn argv=/usr/lib/ifmail/ifmail -r \$nexthop (\$recipient)
#
#bsmtp     unix  -       n       n       -       -       pipe
#  flags=Fq. user=bsmtp argv=/usr/local/sbin/bsmtp -f \$sender \$nexthop \$recipient
#
#scalemail-backend unix -       n       n       -       2       pipe
#  flags=R user=scalemail argv=/usr/lib/scalemail/bin/scalemail-store
#  \${nexthop} \${user} \${extension}
#
#mailman   unix  -       n       n       -       -       pipe
#  flags=FR user=list argv=/usr/lib/mailman/bin/postfix-to-mailman.py
#  \${nexthop} \${user}
PASTECONFIGURATIONFILE
cat > /etc/postfix/vmaps << PASTECONFIGURATIONFILE
info@example.com example.com/info/
catchall@example.com example.com/catchall/
@example.com example.com/catchall/
PASTECONFIGURATIONFILE
cat > /etc/postfix/dhparams.pem << PASTECONFIGURATIONFILE
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA89cQboI15ovwWXqbPoy1hcTqeQquI3rJ1DNZYhz33Od/peqIb2V6
DK15WY/6GuZl8OEGqPTUDOveKxiAtGlRcXMGBVihlnb8v4cZthiCAEn9+z7U3Ddn
nAgfJ9ImW5nQCFMbSxAQM/Qt1ghMkkOOa4UMsEQVxgCW5kCK9pOyzd32obyHzdXP
sHCt24OIcKJTMf1WzPjcY6S9nStdSEmgcfBcxGF3uIaxG2oeycwfAFXyaBYelERk
EKeXTLNsLOii4QPl0EtYzipc21uqBOce8PzH6bQluULip9IrnP34OOB+RZT6M4NU
YIrwf/GlpT6Akog46a9XBMduAfeb50ONwwIBAg==
-----END DH PARAMETERS-----
PASTECONFIGURATIONFILE
cat > /etc/postfix/smtp_header_checks << PASTECONFIGURATIONFILE
/^\\s*Received:.*with ESMTPSA/ IGNORE
/^\\s*X-Originating-IP:/ IGNORE
/^\\s*X-Enigmail/ IGNORE
/^\\s*X-Mailer:/	IGNORE
/^\\s*User-Agent:/ IGNORE
PASTECONFIGURATIONFILE
cat > /etc/postfix/check_recipient_access << PASTECONFIGURATIONFILE
foo@bar.com 550 Does not exist.
qoo@bar.com REJECT
PASTECONFIGURATIONFILE
cat > /etc/postfix/check_sender_access << PASTECONFIGURATIONFILE
importantcompany.com OK
spammer.cn REJECT
PASTECONFIGURATIONFILE
cat > /etc/logrotate.d/dovecot << PASTECONFIGURATIONFILE
/var/log/dovecot
/var/log/dovecot.info
{
  missingok
  notifempty
  sharedscripts
  delaycompress
  postrotate
    doveadm log reopen
  endscript
}
PASTECONFIGURATIONFILE
cat > /etc/opendkim.conf << PASTECONFIGURATIONFILE
PidFile	/var/run/opendkim/opendkim.pid
Syslog	yes
SyslogSuccess	yes
LogWhy	yes
UserID	opendkim:opendkim
Socket	inet:8891@localhost
Umask	002

Mode	sv
SendReports	no
# ReportAddress	"Example.com Postmaster" <postmaster@example.com>
SoftwareHeader	no

Canonicalization	relaxed/relaxed
MinimumKeyBits	1024

KeyTable	/etc/opendkim/KeyTable
SigningTable	refile:/etc/opendkim/SigningTable

##  Identifies a set of "external" hosts that may send mail through the server as one
##  of the signing domains without credentials as such.
# ExternalIgnoreList	refile:/etc/opendkim/TrustedHosts

##  Identifies a set "internal" hosts whose mail should be signed rather than verified.
# InternalHosts	refile:/etc/opendkim/TrustedHosts

##  Contains a list of IP addresses, CIDR blocks, hostnames or domain names
##  whose mail should be neither signed nor verified by this filter.  See man
##  page for file format.
# PeerList	X.X.X.X

OversignHeaders	From

PASTECONFIGURATIONFILE
cat > /etc/opendkim/keys/example.com/20190714T225318.private << PASTECONFIGURATIONFILE
-----BEGIN RSA PRIVATE KEY-----
MIICWwIBAAKBgQDYV1LKMUQMa20a443NTCBM+TjJSpeRR8HaNMFfpCpLUnxRJSXl
6zWJGtyo/mU8yJNmH0Z31FHqMYmyOc8Rw6Jxqr92uk6VI7GB2yZ0UJqz2Q54wrPE
5rapFD5Gak3WaS5iBwwiMxusfp5WKNpxH/CTWyqk7IH072aSWIqVzoHj4wIDAQAB
AoGAa7knn0hiwvBm9oGiZTxnxQw/63M5/3xEmZu1QiNjb/gVsO4XbeHt2WRHxdpO
nLKfOrWOCDLvyvZ5wwYoBodshdSKoNwwTtNQyx9imtvwheLszXWdVnfweV8z7FhZ
lsp/qxRP+4AEdHAYAPemagmpzrrdxirXCEP7K0WpH60WxikCQQDsCNUzzF7aOBUO
Z1gdgwSRnoEseK8u/57WKSfcKYmcEvp7nxPIFnmIBrsjmRGl1BLPJHFVKj3nmYX7
bHeuXPgtAkEA6qQLHj3oN+Oj8o2HaxX50yn0+qVlrX5f2wYNka4p7CU4vhphmL+E
j44M0fiFQ8+Kl0UN0EVbdTGN3AkvX+lGTwJAY2rFAnBOc3OzysFUp/mLbxpoJicf
ApjAekwTcfQ89fQ4dOFoH5r3zYeoQzIx8LsGwSEEa27DbE2J1YC2WEbocQJAakqV
nsV8hJTil+X1ClWSLk47Y6+5N7afxaAgVXYIF6lk4vkgbQmVC1LWC+gAto81wQDP
GSHSJGymTp76jwAlkQJACJw5N9kk4mJeNDv+v0a/27Y1BLaGtdbPeC9p2GPD/Cmd
c0g+xr3WAzLt+QFadz2VTaBTwBYwfI/a0ncsLYEWfw==
-----END RSA PRIVATE KEY-----
PASTECONFIGURATIONFILE
cat > /etc/opendkim/keys/example.com/20190714T225318.txt << PASTECONFIGURATIONFILE
20190714T225318._domainkey.example.com.	IN	TXT	( "v=DKIM1; k=rsa; "
	  "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDYV1LKMUQMa20a443NTCBM+TjJSpeRR8HaNMFfpCpLUnxRJSXl6zWJGtyo/mU8yJNmH0Z31FHqMYmyOc8Rw6Jxqr92uk6VI7GB2yZ0UJqz2Q54wrPE5rapFD5Gak3WaS5iBwwiMxusfp5WKNpxH/CTWyqk7IH072aSWIqVzoHj4wIDAQAB" )  ; ----- DKIM key 20190714T225318 for example.com
PASTECONFIGURATIONFILE
cat > /etc/opendkim/SigningTable << PASTECONFIGURATIONFILE
*@example.com 20190714T225318._domainkey.example.com

PASTECONFIGURATIONFILE
cat > /etc/opendkim/KeyTable << PASTECONFIGURATIONFILE
20190714T225318._domainkey.example.com example.com:20190714T225318:/etc/opendkim/keys/exampel.com/20190714T225318.private
PASTECONFIGURATIONFILE
# COPY CONFIGURATION FILES

alternatives --set mta /usr/sbin/sendmail.postfix
sudo groupadd -g 5000 vmail
sudo useradd -m -u 5000 -g 5000 -s /bin/bash vmail
postmap /etc/postfix/vmaps
postmap /etc/postfix/smtp_header_checks

chmod +x /usr/local/sbin/adddovecotuser
chmod +x /usr/local/sbin/deldovecotuser

openssl dhparam -out /etc/postfix/dhparams.pem 2048

postconf -e "alias_maps = hash:/etc/aliases" # fix NIS warning as default config is "alias_maps = hash:/etc/aliases, nis:mail.aliases"

firewall-cmd --permanent --add-service=smtp
firewall-cmd --permanent --add-port=465/tcp
firewall-cmd --permanent --add-service=pop3

# rate limit tcp connections to pop3s on 995/tcp to 8 / minute per IP
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT_direct 10 -p tcp --dport 995 -m state --state NEW -m recent --set --name POP3S_RATELIMIT
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT_direct 11 -p tcp --dport 995 -m state --state NEW -m recent --update --seconds 60 --hitcount 9 -j REJECT --reject-with tcp-reset --name POP3S_RATELIMIT
firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT_direct 10 -p tcp --dport 995 -m state --state NEW -m recent --set --name POP3S_RATELIMIT
firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT_direct 11 -p tcp --dport 995 -m state --state NEW -m recent --update --seconds 60 --hitcount 9 -j REJECT --reject-with tcp-reset --name POP3S_RATELIMIT

firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
firewall-cmd --direct --get-all-rules # list rate limiting rules [optional]
systemctl start saslauthd
systemctl enable saslauthd
systemctl status saslauthd
systemctl start dovecot
systemctl enable dovecot
systemctl status dovecot
systemctl start postfix
systemctl enable postfix
systemctl status postfix # check status [optional]
systemctl start opendkim
systemctl enable opendkim
systemctl status opendkim

