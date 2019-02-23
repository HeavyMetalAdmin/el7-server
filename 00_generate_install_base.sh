#!/bin/bash
cat 01_install_base.src | grep "# COPY SSH CONFIGURATION FILES" -B 10000000
for i in $(find ssh -type d | sed 's/ssh//' | grep -v '^$'); do
	echo "mkdir -p ${i}"
done
for i in $(find ssh -type f | sed 's/ssh//' | grep -v '^$'); do
	if [ "$(file --mime-type "i3/${i}" | grep "text/")" ]; then
		echo "cat > ${i} << PASTECONFIGURATIONFILE"
		cat ssh/${i} | sed 's/\\/\\\\/g;s/\$/\\\$/g;s/`/\\`/g;'
		echo "PASTECONFIGURATIONFILE"
	else
		echo "base64 -d > ${i} << PASTECONFIGURATIONFILE"
		base64 ssh/${i} | sed 's/\\/\\\\/g;s/\$/\\\$/g;s/`/\\`/g;'
		echo "PASTECONFIGURATIONFILE"	
	fi
done
cat 01_install_base.src | grep "# COPY SSH CONFIGURATION FILES" -A 10000000
