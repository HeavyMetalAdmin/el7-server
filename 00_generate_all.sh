#!/bin/bash
./00_generate_install_base.sh > 01_install_base.sh; chmod u+x 01_install_base.sh
./00_generate_install_http.sh > 02_install_http.sh; chmod u+x 02_install_http.sh
./00_generate_install_ns1.sh > 02_install_ns1.sh; chmod u+x 02_install_ns1.sh
./00_generate_install_ns2.sh > 02_install_ns2.sh; chmod u+x 02_install_ns2.sh
./00_generate_install_mx.sh > 02_install_mx.sh; chmod u+x 02_install_mx.sh
