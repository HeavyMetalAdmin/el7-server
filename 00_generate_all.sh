#!/bin/bash
./00_generate_install.sh 01_install_base.src ssh  > 01_install_base.sh; chmod u+x 01_install_base.sh
./00_generate_install.sh 02_install_http.src http > 02_install_http.sh; chmod u+x 02_install_http.sh
./00_generate_install.sh 02_install_ns.src   ns1  > 02_install_ns1.sh;  chmod u+x 02_install_ns1.sh
./00_generate_install.sh 02_install_ns.src   ns2  > 02_install_ns2.sh;  chmod u+x 02_install_ns2.sh
./00_generate_install.sh 02_install_mx.src   mx   > 02_install_mx.sh;   chmod u+x 02_install_mx.sh
