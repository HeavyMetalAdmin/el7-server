#!/bin/bash
yum -y install deltarpm coreutils net-tools

# update
yum -y update

# ensure we have regular kernel and not custom stuff
yum -y install kernel
grub2-mkconfig --output=/boot/grub2/grub.cfg

# remove provider monitoring, setup and "backdoor" stuff
yum -y remove cloud-init vzdummy-systemd-el7.noarch
# ovh
sed '/^[^#]/ s_\(^.*/usr/local/rtm/bin/rtm.*$\)_#\1_g' -i /etc/crontab
killall -9 rtm

# time stuff
yum -y install chrony
systemctl start chronyd 
systemctl enable chronyd 
systemctl status chronyd # chech status [optional] 
timedatectl set-timezone UTC
# FIX for https://bugzilla.redhat.com/show_bug.cgi?id=1088021
yum -y install rsyslog
systemctl stop rsyslog
rm /var/lib/rsyslog/imjournal.state
systemctl start rsyslog
systemctl enable rsyslog

# auto updates
yum install -y yum-cron cronie
sed 's/apply_updates = no/apply_updates = yes/' -i /etc/yum/yum-cron.conf
systemctl start crond
systemctl enable crond
systemctl status crond
systemctl start yum-cron.service
systemctl enable yum-cron.service
systemctl status yum-cron.service # check status [optional]
#journalctl -xn # in case something went wrong

# automatic reboots if libraries or kernel updated
yum install -y yum-utils # for needs-restarting
echo '#!/bin/bash' > /etc/cron.hourly/9needs-restarting.cron
echo "needs-restarting -r > /dev/null || shutdown -r" >> /etc/cron.hourly/9needs-restarting.cron
chmod +x /etc/cron.hourly/9needs-restarting.cron

# ssh and firewall

## firewall
yum -y install firewalld
systemctl restart dbus # FIX: ERROR: Exception DBusException: org.freedesktop.DBus.Error.AccessDenied: Connection ":1.44" is not allowed to own the service "org.fedoraproject.FirewallD1" due to security policies in the configuration file
systemctl start firewalld
systemctl enable firewalld
systemctl status firewalld
firewall-cmd --permanent --zone=public --change-interface="$(ip route | grep default | grep -Po '(?<=dev )(\S+)')"

## ssh
yum install -y openssh
rm -r /etc/ssh/*
ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key # re-generate public key
yum -y install policycoreutils-python

# COPY CONFIGURATION FILES
mkdir -p /etc
mkdir -p /etc/ssh
mkdir -p /etc/yum
mkdir -p /usr
mkdir -p /usr/local
mkdir -p /usr/local/sbin
cat > /etc/ssh/sshd_config << PASTECONFIGURATIONFILE
# change port, obscurity is a valid security layer!
Port 226

# VERBOSE login to log user's key fingerprints on login.
LogLevel VERBOSE
SyslogFacility AUTHPRIV

HostKey /etc/ssh/ssh_host_ed25519_key
AuthorizedKeysFile %h/.ssh/authorized_keys
#RevokedKeys /etc/ssh/revokeyd_keys # TODO: check if this works

PermitRootLogin prohibit-password # NOTE: change to 'no' for multiuser system
UsePAM yes

AuthenticationMethods publickey #,keyboard-interactive # TODO: do 2FA or kerberos
PubkeyAuthentication yes
PermitEmptyPasswords no
HostbasedAuthentication no
PasswordAuthentication no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
ExposeAuthenticationMethods never

X11Forwarding no
IgnoreRhosts yes

StrictModes yes
UsePrivilegeSeparation sandbox

MaxAuthTries 1

PASTECONFIGURATIONFILE
cat > /etc/logrotate.conf << PASTECONFIGURATIONFILE
# see "man logrotate" for details
# rotate log files weekly
weekly

# keep 4 weeks worth of backlogs
rotate 8

# create new (empty) log files after rotating old ones
create

# use date as a suffix of the rotated file
dateext

# uncomment this if you want your log files compressed
#compress

# RPM packages drop log rotation information into this directory
include /etc/logrotate.d

# no packages own wtmp and btmp -- we'll rotate them here
/var/log/wtmp {
    monthly
    create 0664 root utmp
	minsize 1M
    rotate 1
}

/var/log/btmp {
    missingok
    monthly
    create 0600 root utmp
    rotate 1
}

# system-specific logs may be also be configured here.
PASTECONFIGURATIONFILE
cat > /etc/yum/yum-cron-hourly.conf << PASTECONFIGURATIONFILE
[commands]
#  What kind of update to use:
# default                            = yum upgrade
# security                           = yum --security upgrade
# security-severity:Critical         = yum --sec-severity=Critical upgrade
# minimal                            = yum --bugfix update-minimal
# minimal-security                   = yum --security update-minimal
# minimal-security-severity:Critical =  --sec-severity=Critical update-minimal
update_cmd = default

# Whether a message should emitted when updates are available.
update_messages = yes

# Whether updates should be downloaded when they are available. Note
# that updates_messages must also be yes for updates to be downloaded.
download_updates = yes

# Whether updates should be applied when they are available.  Note
# that both update_messages and download_updates must also be yes for
# the update to be applied
apply_updates = yes

# Maximum amout of time to randomly sleep, in minutes.  The program
# will sleep for a random amount of time between 0 and random_sleep
# minutes before running.  This is useful for e.g. staggering the
# times that multiple systems will access update servers.  If
# random_sleep is 0 or negative, the program will run immediately.
random_sleep = 15


[emitters]
# Name to use for this system in messages that are emitted.  If
# system_name is None, the hostname will be used.
system_name = None

# How to send messages.  Valid options are stdio and email.  If
# emit_via includes stdio, messages will be sent to stdout; this is useful
# to have cron send the messages.  If emit_via includes email, this
# program will send email itself according to the configured options.
# If emit_via is None or left blank, no messages will be sent.
emit_via = stdio

# The width, in characters, that messages that are emitted should be
# formatted to.
output_width = 80


[email]
# The address to send email messages from.
# NOTE: 'localhost' will be replaced with the value of system_name.
email_from = root

# List of addresses to send messages to.
email_to = root

# Name of the host to connect to to send email messages.
email_host = localhost


[groups]
# List of groups to update
group_list = None

# The types of group packages to install
group_package_types = mandatory, default

[base]
# This section overrides yum.conf

# Use this to filter Yum core messages
# -4: critical
# -3: critical+errors
# -2: critical+errors+warnings (default)
debuglevel = -2

# skip_broken = True
mdpolicy = group:main

# Uncomment to auto-import new gpg keys (dangerous)
# assumeyes = True
PASTECONFIGURATIONFILE
cat > /etc/yum/yum-cron.conf << PASTECONFIGURATIONFILE
[commands]
#  What kind of update to use:
# default                            = yum upgrade
# security                           = yum --security upgrade
# security-severity:Critical         = yum --sec-severity=Critical upgrade
# minimal                            = yum --bugfix update-minimal
# minimal-security                   = yum --security update-minimal
# minimal-security-severity:Critical =  --sec-severity=Critical update-minimal
update_cmd = default

# Whether a message should be emitted when updates are available,
# were downloaded, or applied.
update_messages = no

# Whether updates should be downloaded when they are available.
download_updates = no

# Whether updates should be applied when they are available.  Note
# that download_updates must also be yes for the update to be applied.
apply_updates = no

# Maximum amout of time to randomly sleep, in minutes.  The program
# will sleep for a random amount of time between 0 and random_sleep
# minutes before running.  This is useful for e.g. staggering the
# times that multiple systems will access update servers.  If
# random_sleep is 0 or negative, the program will run immediately.
# 6*60 = 360
random_sleep = 360


[emitters]
# Name to use for this system in messages that are emitted.  If
# system_name is None, the hostname will be used.
system_name = None

# How to send messages.  Valid options are stdio and email.  If
# emit_via includes stdio, messages will be sent to stdout; this is useful
# to have cron send the messages.  If emit_via includes email, this
# program will send email itself according to the configured options.
# If emit_via is None or left blank, no messages will be sent.
emit_via = stdio

# The width, in characters, that messages that are emitted should be
# formatted to.
output_width = 80


[email]
# The address to send email messages from.
# NOTE: 'localhost' will be replaced with the value of system_name.
email_from = root@localhost

# List of addresses to send messages to.
email_to = root

# Name of the host to connect to to send email messages.
email_host = localhost


[groups]
# NOTE: This only works when group_command != objects, which is now the default
# List of groups to update
group_list = None

# The types of group packages to install
group_package_types = mandatory, default

[base]
# This section overrides yum.conf

# Use this to filter Yum core messages
# -4: critical
# -3: critical+errors
# -2: critical+errors+warnings (default)
debuglevel = -2

# skip_broken = True
mdpolicy = group:main

# Uncomment to auto-import new gpg keys (dangerous)
# assumeyes = True
PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-firewall_remove_whitelist_ssh << PASTECONFIGURATIONFILE
#!/bin/bash
if [ \$# -gt 1 ]; then
	echo "Remove SSH IP from white list"
	echo
	echo "usage: \${0} [IP]"
	echo
	echo "If IP is not given IP from \\\$SSH_CLIENT will be used."
	echo
	exit 1
fi
if [ \$# -eq 0 ]; then
	IP="\$(echo \$SSH_CLIENT | cut -d' ' -f1)"
	echo "No IP given using IP from \\\$SSH_CLIENT (\${IP})"
else
	IP="\${1}"
fi
firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT_direct 0 -p tcp -s "\${IP}" --dport 226 -m state --state NEW -j ACCEPT
firewall-cmd --reload

PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-firewall_add_whitelist_ssh << PASTECONFIGURATIONFILE
#!/bin/bash
if [ \$# -gt 1 ]; then
	echo "Whitelist the SSH IP"
	echo
	echo "usage: \${0} [IP]"
	echo
	echo "If IP is not given IP from \\\$SSH_CLIENT will be used."
	echo
	exit 1
fi
if [ \$# -eq 0 ]; then
	IP="\$(echo \$SSH_CLIENT | cut -d' ' -f1)"
	echo "No IP given using IP from \\\$SSH_CLIENT (\${IP})"
else
	IP="\${1}"
fi
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT_direct 0 -p tcp -s "\${IP}" --dport 226 -m state --state NEW -j ACCEPT
firewall-cmd --reload

PASTECONFIGURATIONFILE
# COPY CONFIGURATION FILES

# make el7- scripts executable
chmod u+x /usr/local/sbin/el7-*

firewall-cmd --permanent --add-port=226/tcp --zone=public
semanage port -a -t ssh_port_t -p tcp 226

# rate limit tcp connections to SSH on 226/tcp to 3 per minute
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT_direct 10 -p tcp --dport 226 -m state --state NEW -m recent --set --name SSH_RATELIMIT
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT_direct 11 -p tcp --dport 226 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j REJECT --reject-with tcp-reset --name SSH_RATELIMIT
firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT_direct 10 -p tcp --dport 226 -m state --state NEW -m recent --set --name SSH_RATELIMIT
firewall-cmd --permanent --direct --add-rule ipv6 filter INPUT_direct 11 -p tcp --dport 226 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j REJECT --reject-with tcp-reset --name SSH_RATELIMIT
systemctl start sshd
systemctl enable sshd
systemctl reload sshd
systemctl status sshd # check status [optional]
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
firewall-cmd --direct --get-all-rules # list rate limiting rules [optional]

hostnamectl set-hostname localhost.localdomain

