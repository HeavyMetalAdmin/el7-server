#!/bin/bash
yum -y install epel-release openssl
yum -y install httpd python-certbot-apache mod_ssl mod_security
rm -rf /etc/httpd/conf/*
rm -rf /etc/httpd/conf.d/*
rm -rf /etc/httpd/conf.modules.d/*
# COPY CONFIGURATION FILES
mkdir -p /etc
mkdir -p /etc/httpd
mkdir -p /etc/httpd/conf
mkdir -p /etc/httpd/conf.d
mkdir -p /etc/httpd/conf.modules.d
mkdir -p /var
mkdir -p /var/www
mkdir -p /var/www/html
mkdir -p /var/www/html/blank
mkdir -p /usr
mkdir -p /usr/local
mkdir -p /usr/local/sbin

PASTECONFIGURATIONFILE
cat > /var/www/html/blank/index.html << PASTECONFIGURATIONFILE
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN"><html><head><title></title><meta name="robots" content="noindex, nofollow, noarchive"><meta http-equiv="content-type" content="text/html; charset=us-ascii"></head><body>This page intentionally left (almost) blank.</body></html>
PASTECONFIGURATIONFILE
cat > /var/www/html/blank/robots.txt << PASTECONFIGURATIONFILE
User-agent: *
Disallow: /
PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-letsencrypt_delete << PASTECONFIGURATIONFILE
#!/bin/bash
if [ \$# -eq 0 ]; then
	echo "Delete a Let's Encrypt certificate for a domain"
	echo
	echo "usage: \${0} <domain>"
	echo
	exit 1
fi
domain=\${1}
certbot delete --cert-name "\${domain}"
PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-letsencrypt_setup << PASTECONFIGURATIONFILE
#!/bin/bash
if [ \$# -eq 0 ]; then
	echo "Gets a Let's Encrypt certificate for a domain"
	echo
	echo "usage: \${0} <domain>"
	echo
	exit 1
fi
domain=\${1}
certbot certonly -n --webroot -w "/var/www/html/\${domain}" -d "\${domain}" --register-unsafely-without-email --rsa-key-size 4096 --agree-tos
PASTECONFIGURATIONFILE
cat > /usr/local/sbin/el7-letsencrypt_fix << PASTECONFIGURATIONFILE
#!/bin/bash
cd /etc/letsencrypt/live
ls | grep -v README | while read domain; do
rm -f \${domain}/cert.pem
ln -s ../\$(ls ../archive/\${domain}/cert*.pem | tail -n1) \${domain}/cert.pem
rm -f \${domain}/chain.pem
ln -s ../\$(ls ../archive/\${domain}/chain*.pem | tail -n1) \${domain}/chain.pem
rm -f \${domain}/fullchain.pem
ln -s ../\$(ls ../archive/\${domain}/fullchain*.pem | tail -n1) \${domain}/fullchain.pem
rm -f \${domain}/privkey.pem
ln -s ../\$(ls ../archive/\${domain}/privkey*.pem | tail -n1) \${domain}/privkey.pem
done
PASTECONFIGURATIONFILE
# COPY CONFIGURATION FILES

# make el7- scripts executable
chmod u+x /usr/local/sbin/el7-*

mkdir -p /etc/httpd/ssl/
openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout /etc/httpd/ssl/snakeoil.key -out /etc/httpd/ssl/snakeoil.crt -subj "/C=XX/L= /O= "
mkdir -p /root/.config/letsencrypt/
echo "rsa-key-size = 4096" > /root/.config/letsencrypt/cli.ini
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
firewall-cmd --list-all # list rules [optional]
systemctl start httpd
systemctl enable httpd
systemctl status httpd
##
## LETS ENCRYPT STUFF
##
mkdir -p /root/.config/letsencrypt/
echo "rsa-key-size = 4096" > /root/.config/letsencrypt/cli.ini
echo "$(expr $RANDOM \% 60) 0,12 * * * root perl -e 'sleep int(rand(3600))'; certbot renew --post-hook 'systemctl reload httpd'" > /etc/cron.d/certbot

