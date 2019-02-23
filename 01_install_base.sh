#!/bin/bash
yum -y install deltarpm coreutils

# update
yum -y update

# ensure we have regular kernel and not custom stuff
yum -y install kernel
grub2-mkconfig --output=/boot/grub2/grub.cfg

# remove provider monitoring, setup and backdoor stuff
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
echo "#\!/bin/bash" > /etc/cron.hourly/9needs-restarting.cron
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

# COPY SSH CONFIGURATION FILES
mkdir -p /etc
mkdir -p /etc/ssh
base64 -d > /etc/ssh/sshd_config << PASTECONFIGURATIONFILE
IyBjaGFuZ2UgcG9ydCwgb2JzY3VyaXR5IGlzIGEgdmFsaWQgc2VjdXJpdHkgbGF5ZXIhClBvcnQg
MjI2CgojIFZFUkJPU0UgbG9naW4gdG8gbG9nIHVzZXIncyBrZXkgZmluZ2VycHJpbnRzIG9uIGxv
Z2luLgpMb2dMZXZlbCBWRVJCT1NFClN5c2xvZ0ZhY2lsaXR5IEFVVEhQUklWCgpIb3N0S2V5IC9l
dGMvc3NoL3NzaF9ob3N0X2VkMjU1MTlfa2V5CkF1dGhvcml6ZWRLZXlzRmlsZSAlaC8uc3NoL2F1
dGhvcml6ZWRfa2V5cwojUmV2b2tlZEtleXMgL2V0Yy9zc2gvcmV2b2tleWRfa2V5cyAjIFRPRE86
IGNoZWNrIGlmIHRoaXMgd29ya3MKClBlcm1pdFJvb3RMb2dpbiBwcm9oaWJpdC1wYXNzd29yZCAj
IE5PVEU6IGNoYW5nZSB0byAnbm8nIGZvciBtdWx0aXVzZXIgc3lzdGVtClVzZVBBTSB5ZXMKCkF1
dGhlbnRpY2F0aW9uTWV0aG9kcyBwdWJsaWNrZXkgIyxrZXlib2FyZC1pbnRlcmFjdGl2ZSAjIFRP
RE86IGRvIDJGQSBvciBrZXJiZXJvcwpQdWJrZXlBdXRoZW50aWNhdGlvbiB5ZXMKUGVybWl0RW1w
dHlQYXNzd29yZHMgbm8KSG9zdGJhc2VkQXV0aGVudGljYXRpb24gbm8KUGFzc3dvcmRBdXRoZW50
aWNhdGlvbiBubwpDaGFsbGVuZ2VSZXNwb25zZUF1dGhlbnRpY2F0aW9uIG5vCktlcmJlcm9zQXV0
aGVudGljYXRpb24gbm8KR1NTQVBJQXV0aGVudGljYXRpb24gbm8KRXhwb3NlQXV0aGVudGljYXRp
b25NZXRob2RzIG5ldmVyCgpYMTFGb3J3YXJkaW5nIG5vCklnbm9yZVJob3N0cyB5ZXMKClN0cmlj
dE1vZGVzIHllcwpVc2VQcml2aWxlZ2VTZXBhcmF0aW9uIHNhbmRib3gKCk1heEF1dGhUcmllcyAx
Cgo=
PASTECONFIGURATIONFILE
# COPY SSH CONFIGURATION FILES

firewall-cmd --permanent --add-port=226/tcp --zone=public
semanage port -a -t ssh_port_t -p tcp 226
systemctl start sshd
systemctl enable sshd
systemctl reload sshd
systemctl status sshd # check status [optional]
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]

