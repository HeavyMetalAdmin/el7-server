#!/bin/bash
if [ $# -eq 0 ]; then
	echo "Gets a Let's Encrypt certificate for a domain"
	echo
	echo "usage: ${0} <domain>"
	echo
	exit 1
fi
domain=${1}
certbot certonly -n --webroot -w /var/www/html/${domain} -d ${domain} --register-unsafely-without-email --rsa-key-size 4096 --agree-tos
