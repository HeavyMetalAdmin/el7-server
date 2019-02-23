#!/bin/bash
cat 02_install_http.src | grep "# COPY HTTP CONFIGURATION FILES" -B 10000000
for i in $(find http -type d | sed 's/http//' | grep -v '^$'); do
	echo "mkdir -p ${i}"
done
for i in $(find http -type f | sed 's/http//' | grep -v '^$'); do
	if [ "$(file --mime-type "http/${i}" | cut -d' ' -f 2 | grep "text/")" ]; then
		echo "cat > ${i} << PASTECONFIGURATIONFILE"
		cat http/${i} | sed 's/\\/\\\\/g;s/\$/\\\$/g;s/`/\\`/g;'
		echo "PASTECONFIGURATIONFILE"
	else
		echo "base64 -d > ${i} << PASTECONFIGURATIONFILE"
		base64 http/${i} | sed 's/\\/\\\\/g;s/\$/\\\$/g;s/`/\\`/g;'
		echo "PASTECONFIGURATIONFILE"
	fi
done
cat 02_install_http.src | grep "# COPY HTTP CONFIGURATION FILES" -A 10000000
