# CENTOS 7 SERVER SCRIPTS

Bootstrap a base CentOS 7 server system starting from a Minimal Install.

Tested on/with:

- CentOS-7-x86_64-Minimal-1804.iso
- OVH VPS
- Kimsufi Server
- EDIS KVM
- Hetzner Cloud Servers
- VPSCHEAP NET

## (Re-)Generate the scripts

```
./00_generate_all.sh
```


## The scripts

The scripts themselves can be installed individually, however, it is recommended
to at least install 01* script before installing any 02* script.

Either run directly on server as `./02_install_http.sh` or run remotely
via SSH as `cat 02_install_http.sh | ssh root@yourserver`

**Note:** In the examples `example.com` and `192.168.42.42` are your servers
domain and/or IP.

### 01_install_base.sh

This sets up auto-updates and private key only SSH login over an alternate SSH port
(to keep the logs clean and not have your SSH listed on Shodan.)

**NOTE:** Please follow these instructions closely, otherwise you may lock
yourself out of your server!

1. Generate a suitable SSH key and copy it onto the machine via:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_hostname
ssh root@192.168.42.42 'mkdir ~/.ssh/'
scp ~/.ssh/id_ed25519_hostname.pub root@192.168.42.42:~/.ssh/authorized_keys
```

2. Open a SSH connection to the server **and keep it open** and perform the following tasks over different SSH connections (so you can recover in case something fails with the SSH setup).

3. Install `01_install_base.sh` by running (on your local machine):

```
cat 01_install_base.sh | ssh root@192.168.42.42
```

4. After installing the `01_install_base.sh` script login in via:

```
ssh root@192.168.42.42 -i ~/.ssh/id_ed25519_hostname -p 226
```

5. If step 4 works you can close the backup SSH connection from step 2.


It is recommended you add the following to your `~/.ssh/config`:

```
host myhostalias
	HostName 192.168.42.42
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
- rate limiting connection attempts to SSH to 3 / min per IP

**WARNING:** The SSH configuration is very restrictive. Take care to not
accidentally lock yourself out of your system. Make sure you have placed a
suitable SSH key (see above) on the machine.

**ADVICE:** It is advised you keep a second SSH connection open to the server
so you can rescue the setup in case you lock yourself out of the system. Only close this second SSH connection when you can connect to the server via the above provided SSH configuration.

**NOTE:** To remove the rate limiting run:
```
firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT_direct 0 -p tcp --dport 226 -m state --state NEW -m recent --set --name SSH_RATELIMIT
firewall-cmd --permanent --direct --remove-rule ipv4 filter INPUT_direct 1 -p tcp --dport 226 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j REJECT --reject-with tcp-reset --name SSH_RATELIMIT
firewall-cmd --permanent --direct --remove-rule ipv6 filter INPUT_direct 0 -p tcp --dport 226 -m state --state NEW -m recent --set --name SSH_RATELIMIT
firewall-cmd --permanent --direct --remove-rule ipv6 filter INPUT_direct 1 -p tcp --dport 226 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j REJECT --reject-with tcp-reset --name SSH_RATELIMIT
firewall-cmd --reload
```

**NOTE:** To see the recent list of IP addresses of this SSH rate-limiting rule run:
```bash
cat /proc/net/ipt_recent/SSH_RATELIMIT
```

**NOTE:** To see possible active rate limiting rules run:

```bash
firewall-cmd --direct --get-all-rules
```
#### TODOs

* Setup knockd: https://www.digitalocean.com/community/tutorials/how-to-use-port-knocking-to-hide-your-ssh-daemon-from-attackers-on-ubuntu


### 02_install_http.sh (Apache and Let's Encrypt)

Installs and configures Apache.

After install edit `/etc/httpd/conf.d/vhost.conf` and add your desired virtual
hosts where it says `# INSERT VHOSTS HERE` as follows:

1. `Use noSSLVhost example.com` gives you a plain HTTP VHost for domain example.com with its webroot being `/var/www/html/example.com`.

2. To generate the webroot run `cp -R /var/www/html/blank/ /var/www/html/example.com`. This copies a standard `robots.txt` and `index.html` file to the new domain.

3. Get a Let's Encrypt certificate for example.com domain via `/usr/local/sbin/el7-letsencrypt_setup example.com`.

4. Change the previous configuration to `Use Vhost example.com`. The domain is now using HTTPS with the configured Let's Encrypt certificate.

To get a domain redirection change the configuration in step 3 above to `Use redirVHost example.com example.org` which will redirect example.com to example.org (both using HTTPS!).


**NOTE:** When connecting to the server without `Host:` header or to its IP or an unknown domain in the `Host:` header it will point to `/var/www/html/blank/` which contains a `robots.txt` which denials all robots. Connecting via HTTPS in addition serves an deliberately weak and outdated certificate. You can change this behavior by editing `/etc/httpd/conf/httpd.conf` yourself.

#### Remove a Let's Encrypt certificate

```
/usr/local/sbin/el7-letsencrypt_delete example.com
```

### 02_install_ns.sh (BIND name server)

Installs and configures BIND name server.

#### DNSSEC

1. To setup DNSSEC for a zone, i.e., generate (or regenerate) keys, etc. run: `/usr/local/sbin/el7-dnssec_setup example.com`
2. To (re-)sign a zone, run: `/usr/local/sbin/el7-dnssec_sign example.com`

#### TODOs

* Automate zone generation / changes
* Automated zone resigning; currently zones are signed with a validity of 1 year
* CDS: does not work in RHEL7

#### Fixes

##### Journal errors

Delete journals:

```
systemctl stop named
rm -f /var/named/*.jnl
systemctl start named
```

### 02_install_mx.sh (Postfix + Dovecot mail server)

Requires: `02_install_http.sh` (to acquire certificate from Let's Encrypt)

This sets up:

- SMTP (25/tcp)
- SMTPs (465/tcp)
- POP3s (995/tcp)
- firewall
- rate limiting connection attempts to POP3s to 3 / min per IP

#### Setup (THIS MUST BE DONE MANUALLY!)

- In `/etc/dovecot/dovecot.conf` and `/etc/postfix/main.cf` replace `mx.example.com` with your domain name.

#### Add a mail box (user)

```
/usr/local/sbin/el7-mx_add_user user@example.com
```

This will generate a postfix mailbox as well as a POP3 Dovecot mailbox.

Mail user can then use:
- SMPTs on 465/tcp with (CRAM-MD5) encrypted password and username `user@example.com`.
- POP3s on 995/tcp with (CRAM-MD5) encrypted password and username `user@example.com`.
- SMTP on 25/tcp to receive mail addressed to `user@example.com`.

#### Delete a mail box (user)

```
/usr/local/sbin/el7-mx_delete_user user@example.com
```

This deletes the postfix and Dovecot mailbox of `user@example.com`.

#### DKIM

Run `/usr/local/sbin/el7-mx_dkim` and follow the instructions.

TODO: automate this

#### TODOs

* Spamassassin: https://www.akadia.com/services/postfix_spamassassin.html
* Rate limiting: http://www.postfix.org/TUNING_README.html#conn_limit
* Backup MX: https://www.howtoforge.com/postfix_backup_mx
* Squirrelmail (as a separate script)
* Whitelists: https://www.howtoforge.com/how-to-whitelist-hosts-ip-addresses-in-postfix
* NS add: `_adsp._domainkey IN TXT "dkim=all"`

Make these work:

- Set the recipient whitelist (these addresses will always receive mail regardless of RBL status) in `/etc/postfix/check_recipient_access`
- Set the sender whitelist (email from these addresses will always be delivered regardless of sender domain, etc.) in `/etc/postfix/check_sender_access`

- Make work with `/etc/selinux/config`: `SELINUX=enforcing`

### 03_install_php.sh (PHP)

Requires: `02_install_http.sh`

#### TODOs

* Cleanup, document and release script, which is basically just a `yum install php`
* Stop using PHP

### 03_install_mysql.sh (MySQL / MariaDB)

Requires: `02_install_http.sh`

#### TODO

* Cleanup, document and release script

## Trouble shooting

### rsyslog

- If you changed the timezone and `journalctl` receives logs, e.g. `journalctl -u postfix`, but `rsyslog` doesn't anymore, e.g. `/var/log/maillog`, you can try (see <https://bugzilla.redhat.com/show_bug.cgi?id=1088021>):

```
rm /var/lib/rsyslog/imjournal.state
systemctl restart rsyslog
```
- To test logging you can issue log events, e.g. into log `mail.info` via: `logger -p mail.info Testing`

### yum

If yum stops working try:

```
package-cleanup --dupes
package-cleanup --cleandupes
yum clean all
yum check
```
or
```
yum-complete-transaction
yum-complete-transaction --cleanup-only
yum clean all
yum check
```

## Future proofing 

- Periodically run and adapt accordingly:
	- testssl
	- <https://ssllabs.com/>
	- <https://mxtoolbox.com/domain/example.com>
- Keep up with:
	- <https://cipherli.st/>

## Key integrity

Make sure to check the integrity of the repository keys!

```
$ for i in $(ls /etc/pki/rpm-gpg/RPM-GPG-KEY-*); do gpg --with-fingerprint "${i}"; done
pub  4096R/0x24C6A8A7F4A80EB5 2014-06-23 CentOS-7 Key (CentOS 7 Official Signing Key) <security@centos.org>
      Key fingerprint = 6341 AB27 53D7 8A78 A7C2  7BB1 24C6 A8A7 F4A8 0EB5
pub  2048R/0xD0F25A3CB6792C39 2014-07-15 CentOS-7 Debug (CentOS-7 Debuginfo RPMS) <security@centos.org>
      Key fingerprint = 759D 690F 6099 2D52 6A35  8CBD D0F2 5A3C B679 2C39
pub  4096R/0xC78893AC8FAE34BD 2014-06-04 CentOS-7 Testing (CentOS 7 Testing content) <security@centos.org>
      Key fingerprint = BA02 A5E6 AFF9 70F7 269D  D972 C788 93AC 8FAE 34BD
pub  1024D/0x309BC305BAADAE52 2009-03-17 elrepo.org (RPM Signing Key for elrepo.org) <secure@elrepo.org>
      Key fingerprint = 96C0 104F 6315 4731 1E0B  B1AE 309B C305 BAAD AE52
sub  2048g/0xF46A3776B8C66E6D 2009-03-17
pub  4096R/0x6A2FAEA2352C64E5 2013-12-16 Fedora EPEL (7) <epel@fedoraproject.org>
      Key fingerprint = 91E9 7D7C 4A5E 96F1 7F3E  888F 6A2F AEA2 352C 64E5
pub  4096R/0xE98BFBE785C6CD8A 2011-06-25 Nux.Ro (rpm builder) <rpm@li.nux.ro>
      Key fingerprint = 561C 96BD 2F7F DC2A DB5A  FD46 E98B FBE7 85C6 CD8A
sub  4096R/0xAB41227CEDD81BD3 2011-06-25
pub  1024D/0x54422A4B98AB5139 2010-05-18 Oracle Corporation (VirtualBox archive signing key) <info@virtualbox.org>
      Key fingerprint = 7B0F AB3A 13B9 0743 5925  D9C9 5442 2A4B 98AB 5139
sub  2048g/0xB6748A65281DDC4B 2010-05-18
```

