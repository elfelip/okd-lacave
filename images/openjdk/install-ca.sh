#!/bin/bash
keytool -noprompt -importcert $CACERTS -storepass changeit -file /tmp/certificats/lacave-root.pem -alias root_lacaveinfo
keytool -noprompt -importcert $CACERTS -storepass changeit -file /tmp/certificats/ca-cert -alias lacaveinfo_new_root
cp /tmp/certificats/* /etc/pki/ca-trust/source/anchors
update-ca-trust extract
rm -rf /tmp/certificats
