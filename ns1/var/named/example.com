$ORIGIN example.com
$TTL 1d
@ IN SOA ns1.example.com. info.example.com. (
	2019011301 ; serial
	12h ; refresh
	1h ; retry
	4w ; expire
	1d ; nx ttl
)

@	IN NS ns1.example.com.
@	IN NS ns2.example.com.
ns1	IN A 1.1.1.1
ns2	IN A 2.2.2.2

@	IN CAA 128 issue "letsencrypt.org"

@	IN MX 1 mx.example.com.
@	IN TXT "v=spf1 mx ip4:4.4.4.4 ip6:0:0:0:0:0:ffff:404:404 -all"
_dmarc	IN TXT "v=DMARC1;p=none;pct=100;ri=600;rua=mailto:dmarc-bie4YeeNeithoxuu@example.com"

@	IN A 3.3.3.3
mx	IN A 4.4.4.4
mx	IN AAAA 0:0:0:0:0:ffff:404:404

