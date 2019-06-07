#!/bin/bash
yum -y install deltarpm coreutils

# update
yum -y update

# ensure we have regular kernel and not custom stuff
yum -y install kernel
grub2-mkconfig --output=/boot/grub2/grub.cfg

# remove provider monitoring, setup and "backdoor" stuff
yum -y remove cloud-init
# ovh
sed '/^[^#]/ s_\(^.*/usr/local/rtm/bin/rtm.*$\)_#\1_g' -i /etc/crontab
killall -9 rtm

# time stuff
yum -y install chrony
systemctl start chronyd 
systemctl enable chronyd 
systemctl status chronyd # chech status [optional] 
timedatectl set-timezone UTC

# auto updates
yum install -y yum-cron
sed 's/apply_updates = no/apply_updates = yes/' -i /etc/yum/yum-cron.conf
systemctl start yum-cron.service
systemctl enable yum-cron.service
systemctl status yum-cron.service # check status [optional]
#journalctl -xn # in case something went wrong

# automatic reboots if libraries or kernel updated
echo '#!/bin/bash' > /etc/cron.hourly/9needs-restarting.cron
echo "needs-restarting -r || shutdown -r" >> /etc/cron.hourly/9needs-restarting.cron
chmod +x /etc/cron.hourly/9needs-restarting.cron


# ssh and firewall

## firewall
yum -y install firewalld
systemctl start firewalld
systemctl enable firewalld
systemctl status firewalld
firewall-cmd --permanent --zone=public --change-interface=$(ip route | grep default | grep -Po '(?<=dev )(\S+)')

## ssh
yum install -y openssh
rm -r /etc/ssh/*
ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key # re-generate public key
yum -y install policycoreutils-python

# COPY CONFIGURATION FILES
mkdir -p /etc
mkdir -p /etc/ssh
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
