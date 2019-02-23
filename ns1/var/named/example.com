$ORIGIN example.com
$TTL 1d
@ IN SOA need.to.know.only. info.example.com. (
	2019011301 ; serial
	1d ; refresh
	1h ; retry
	4w ; expire
	1d ; nx ttl
)

@	IN NS ns1.example.com.
@	IN NS ns2.example.com.
ns1	IN A 1.1.1.1
ns2	IN A 2.2.2.2

@	IN CAA 128 issue "letsencrypt.org"

@	IN MX 1 mxlb.ispgateway.de.
@	IN TXT "v=spf1 mx include:ispgateway.de -all"

@	IN A 3.3.3.3

