#!/bin/bash
cat 02_install_mx.src | grep "# COPY MX CONFIGURATION FILES" -B 10000000
for i in $(find mx -type d | sed 's/mx//' | grep -v '^$'); do
	echo "mkdir -p ${i}"
done
for i in $(find mx -type f | sed 's/mx//' | grep -v '^$'); do
	if [ "$(file --mime-type "mx/${i}" | cut -d' ' -f 2 | grep "text/")" ]; then
		echo "cat > ${i} << PASTECONFIGURATIONFILE"
		cat mx/${i} | sed 's/\\/\\\\/g;s/\$/\\\$/g;s/`/\\`/g;'
		echo "PASTECONFIGURATIONFILE"
	else
		echo "base64 -d > ${i} << PASTECONFIGURATIONFILE"
		base64 mx/${i} | sed 's/\\/\\\\/g;s/\$/\\\$/g;s/`/\\`/g;'
		echo "PASTECONFIGURATIONFILE"
	fi
done
cat 02_install_mx.src | grep "# COPY MX CONFIGURATION FILES" -A 10000000
