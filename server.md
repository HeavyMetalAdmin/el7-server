# CentOS 7 64bit

How to do a CentOS/RHEL 7 basic server install.

## BASE INSTALL

### NETWORK & HOSTNAME

Check `Connect automatically`

### DATE & TIME

Set time zone and enable NTP.

### INSTALLATION SOURCE

If network faster than installation medium:

`On the network: http://mirror.centos.org/centos/7/os/x86_64/`

Otherwise leave as is, i.e. "Local Media".

### SOFTWARE SELECTION

`Minimal Install`

### INSTALLATION DESTINATION

Automatic works ... even for only 2 GiB HDD.

May want to do separate `/home` and  `/tmp` and mount `noexec`.

### SECURITY POLICY

TODO


## SETUP

This setup steps also work for:

* OVH VPS SSD
* Kimsufi


### Update

Update as early as possible. May need to "Setup Network" (see below) first.

```
yum update
```


### Firewall

May need to "Setup Network" (see below) first.

```
yum install -y firewalld
systemctl start firewalld
systemctl enable firewalld
systemctl status firewalld # check status [optional]
#journalctl -xn # in case something went wrong
ip link
firewall-cmd --permanent --zone=public --change-interface=eth0 # or ethX!
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
```

### Setup Network

Not needed if network setup correctly during installation.

```
yum install -y NetworkManager-tui
nmtui # check auto connect
systemctl restart network.service
systemctl enable network.service
```

### Kernel [optional]

Ensure normal kernel instead of custom provider stuff.

```
yum install kernel
grub2-mkconfig --output=/boot/grub2/grub.cfg
```

### Time

```
yum -y install chrony
systemctl start chronyd 
systemctl enable chronyd 
systemctl status chronyd # ckech status [optional] 
timedatectl set-timezone UTC
```

### SSH [optional]

yum install -y openssh
firewall-cmd --permanent --add-port=226/tcp --zone=public
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
# ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_hostname
# scp ~/.ssh/id_ed25519_hostname.pub srv:~/.ssh/authorized_keys # add public key
# scp ./ssh/etc/ssh/sshd_config srv:/etc/ssh/sshd_config
rm -f /etc/ssh/ssh_host_*_key
ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key # re-generate public key
sudo yum install policycoreutils-python
semanage port -a -t ssh_port_t -p tcp 226
systemctl restart sshd
systemctl status sshd # check status [optional]
#journalctl -xn # in case something went wrong

### Auto Updates

```
yum install -y yum-cron
sed 's/apply_updates = no/apply_updates = yes/' -i /etc/yum/yum-cron.conf
systemctl start yum-cron.service
systemctl enable yum-cron.service
systemctl status yum-cron.service # check status [optional]
#journalctl -xn # in case something went wrong
```

#### Automatic reboots after updates of libraries

```
echo "#\!/bin/bash" > /etc/cron.hourly/9needs-restarting.cron
echo "needs-restarting -r || shutdown -r" >> /etc/cron.hourly/9needs-restarting.cron
chmod +x /etc/cron.hourly/9needs-restarting.cron
```

### DNS

#### NS1 and NS2

```
yum install -y bind bind-utils
```

#### NS1

```
# scp ./ns1/etc/named.conf ns1:/etc/. # copy to server
# scp ./ns1/etc/named.rfc1912.zones ns1:/etc/. # copy to server
# scp ./ns1/var/named/* ns1:/var/named/. # copy to server
named-checkconf # check configuration [optional]
named-checkzone example.com /var/named/example.com # check the zone files [optional]
```

#### NS2

```
# scp ./ns2/etc/named.conf ns2:/etc/.
# scp ./ns2/etc/named.rfc1912.zones ns2:/etc/.
```

#### NS1 & NS2

```
firewall-cmd --permanent --zone=public --add-service=dns
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
systemctl start named
systemctl enable named
systemctl status named # check status [otional]
#journalctl -xn # in case something went wrong
```

### Mail


MX1 and MX2: https://www.howtoforge.com/postfix_backup_mx
Strip headers: https://www.void.gr/kargig/blog/2013/11/24/anonymize-headers-in-postfix/

Encrypt outgoing: https://github.com/infertux/zeyple

TODO

```
yum install -y postfix
alternatives --set mta /usr/sbin/sendmail.postfix
systemctl start postfix
systemctl enable postfix
systemctl status postfix # check status [optional]
firewall-cmd --permanent --zone=public --add-service=smtp
firewall-cmd --reload

yum -y install dovecot

```

### Webserver

```
yum install -y epel-release
yum -y install httpd mod_ssl python-certbot-apache mod_security
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
echo "# no welcome page" > /etc/httpd/conf.d/welcome.conf
sed 's|#DocumentRoot "/var/www/html"|DocumentRoot "/var/www/html"|' -i /etc/httpd/conf.d/ssl.conf
sed 's/Options Indexes FollowSymLinks/Options FollowSymLinks/' -i /etc/httpd/conf/httpd.conf
echo 'ServerSignature Off' >> /etc/httpd/conf/httpd.conf
echo 'ServerTokens Prod' >> /etc/httpd/conf/httpd.conf
systemctl start httpd
systemctl enable httpd
systemctl status httpd

# https://cipherli.st

openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout /etc/httpd/ssl/snakeoil.key -out /etc/httpd/ssl/snakeoil.crt


mkdir -p /root/.config/letsencrypt/
echo "rsa-key-size = 4096" > /root/.config/letsencrypt/cli.ini

# certbot doesn't understand mod_macro
#certbot --apache -d example.com -d www.example.com --register-unsafely-without-email
certbot certonly -n --webroot -w /var/www/html/example.com -d example.com --register-unsafely-without-email --rsa-key-size 4096 --agree-tos

certbot certonly -n --register-unsafely-without-email --rsa-key-size 4096 --agree-tos -d test.tld --standalone

echo "0 1,11 * * * root sleep $(expr $RANDOM \% 3600); certbot renew --post-hook 'systemctl reload httpd'" > /etc/cron.d/certbot
systemctl start httpd
systemctl enable httpd
systemctl status httpd
```


### MySQL

```
yum install mariadb-server
systemctl start mariadb                                                           
systemctl enable mariadb
mysql_secure_installation
mysql -u root -p
create database 'db';
# add user
create user 'user'@localhost identified by 'pwd';
# access rights
grant all on db.* to 'user';
# switch db
use db
# create table
CREATE TABLE names (id INT, name VARCHAR(20));
# insert into table
INSERT INTO names VALUES (1,'John'),(2,'Jane');
```

### PHP

```
sudo yum install php-mysqli
```


# TODO:
/etc/rsyslog.conf

/etc/logrotate.conf
/etc/logrotate.d/*


### SFTP




