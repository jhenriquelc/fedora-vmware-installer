#!/usr/bin/bash

if [ $UID -ne 0 ]; then
    echo "MOK test script must be invoked as root because the private key is protected."
    exit 1
fi

if [[ -f "/etc/pki/akmods/private/private_key.priv" ]]; then
    echo "akmods MOK is present."
    echo "MOK enrollment status:"
    mokutil --test-key /etc/pki/akmods/certs/public_key.der
else
    echo "akmods MOK is unavailable."
fi
