#!/bin/bash

yum install -y xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-apps

sed 's/X11Forwarding no/X11Forwarding yes/g' -i /etc/ssh/sshd_config

systemctl restart sshd


