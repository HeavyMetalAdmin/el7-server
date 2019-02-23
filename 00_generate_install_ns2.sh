#!/bin/bash
cat 02_install_ns.src | grep "# COPY NS CONFIGURATION FILES" -B 10000000
for i in $(find ns2 -type d | sed 's/ns2//' | grep -v '^$'); do
	echo "mkdir -p ${i}"
done
for i in $(find ns2 -type f | sed 's/ns2//' | grep -v '^$'); do
	if [ "$(file --mime-type "ns2/${i}" | cut -d' ' -f 2 | grep "text/")" ]; then
		echo "cat > ${i} << PASTECONFIGURATIONFILE"
		cat ns2/${i} | sed 's/\\/\\\\/g;s/\$/\\\$/g;s/`/\\`/g;'
		echo "PASTECONFIGURATIONFILE"
	else
		echo "base64 -d > ${i} << PASTECONFIGURATIONFILE"
		base64 ns2/${i} | sed 's/\\/\\\\/g;s/\$/\\\$/g;s/`/\\`/g;'
		echo "PASTECONFIGURATIONFILE"
	fi
done
cat 02_install_ns.src | grep "# COPY NS CONFIGURATION FILES" -A 10000000
