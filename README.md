---
title: CENTOS 7 SERVER SCRIPTS
---

Bootstrap a base CentOS 7 server system starting from a Minimal Install.

Tested on/with:

- CentOS-7-x86_64-Minimal-1804.iso
- OVH VPS
- Kimsufi Server
- EDIS KVM
- Hetzner Cloud Servers


# (Re-)Generate the scripts

```
./00_generate_all.sh
```


# The scripts

The scripts themselves can be installed individually, however, it is recommended
to at least install 01* script before installing any 02* script.

Either run directly on server as `./02_install_http.sh` or run remotely
via SSH as `cat 02_install_http.sh | ssh root@yourserver`


## 01_install_base.sh

**NOTE:** Please generate a suitable SSH key and copy it onto the machine via:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_hostname
ssh root@192.168.56.102 'mkdir ~/.ssh/'
scp ~/.ssh/id_ed25519_hostname.pub root@192.168.56.102:~/.ssh/authorized_keys
```

After the installing the `01_install_base.sh` script you can login via:

```
ssh root@192.168.56.102 -i ~/.ssh/id_ed25519_hostname -p 226
```

However, it is recommended you add the following to your `~/.ssh/config`:

```
host myhostalias
	HostName 192.168.56.102
	Port 226
	IdentityFile ~/.ssh/id_ed25519_hostname
	User root
```

And then simply login via:

```
ssh myhostalias
```


The `01_install_base.sh` installs and configures:

- Standard kernel (to ensure security updates) 
- Time
- Auto updates with auto reboots on library and kernel updates
- SSH (pubkey only, ed25519 only, and port 226 (for additional security))
- firewall

**WARNING:** The SSH configuration is very restrictive. Take care to not
accidentally lock yourself out of your system. Make sure you have placed a
suitable SSH key (see above) on the machine.

**ADVICE:** It is advised you keep a second SSH connection open to the server
so you can rescue the setup in case you lock yourself out of the system.

## 02_install_http.sh (Apache and Let's Encrypt)

Installs and configures Apache.

After install edit `/etc/httpd/conf.d/vhost.conf` and add your desired virtual
hosts where it says `# INSERT VHOSTS HERE` as follows:

1. `Use noSSLVhost example.com` gives you a plain HTTP VHost for domain example.com with its webroot being `/var/www/html/example.com`

2. Get a Let's Encrypt certificate for example.com domain via `./03_install_letsencrypt.sh example.com`.

3. Change the previous configuration to `Use Vhost example.com`. The domain is now using HTTPS with the configured Let's Encrypt certificate.

To get a domain redirection changes the configuration in step 3 above to `Use redirVHost example.com example.org` which will redirect example.com to example.org (both using HTTPS!).


**NOTE:** When connecting to the server without `Host:` header or to its IP or an unknown domain in the `Host:` header it will point to `/var/www/html/blank/` which contains a `robots.txt` which denials all robots. Connecting via HTTPS in addition serves an deliberately weak and outdated certificate. You an change this behavior by editing `/etc/httpd/conf/httpd.conf` yourself.

### TODOs

* Automate setting up domain and Let's Encrypt certificates.
* `redirVHost` should first redirect to HTTPs on the same domain as requested, then redirect to final host, so it satisfies HSTS requirements.


## 02_install_ns.sh (BIND name server)

### TODOs

* Automate zone generation / changes

## 02_install_mx.sh (Postfix + Dovecot mail server)

Requires: `02_install_http.sh` (to acquire certificate from Let's Encrypt)

### TODO

* DKIM, DMARC: https://www.linode.com/docs/email/postfix/configure-spf-and-dkim-in-postfix-on-debian-8/
* Spamassassin: https://www.akadia.com/services/postfix_spamassassin.html
* Rate limiting: http://www.postfix.org/TUNING_README.html#conn_limit
* Backup MX: https://www.howtoforge.com/postfix_backup_mx
* Squirrelmail (as a separate script)

## 03_install_php.sh (PHP)

Requires: `02_install_http.sh`

### TODO

* Cleanup, document and release script, which is basically just a `yum install php`


## 03_install_mysql.sh (MySQL / MariaDB)

Requires: `02_install_http.sh`

### TODO

* Everything




