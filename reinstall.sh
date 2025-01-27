#!/bin/bash
# fedora-vmware-installer reinstall script
# this script runs every boot via vm-host-modules-reinstal.service
# you may run it manually if the service fails

echo "Starting..."

if ! (modinfo vmmon vmnet); then # modules aren't installed
    pushd .
    cd /opt/vm-host-modules/ || exit 5

        echo "Rebuilding and reinstalling modules..."

        make clean
        make && make install
        make clean

    popd || exit 6
fi

if ! (modprobe vmmon vmnet) ; then # modules aren't loaded
    echo "Detected modules rejection, attempting fix for SecureBoot..."
    if mokutil --sb-state | grep -q "SecureBoot enabled" ; then # modules aren't signed
        if [[ ! -f "/etc/pki/akmods/private/private_key.priv" ]] ; then # can't sign modules
            echo "You're using secure boot but don't seem to have a self-signing key present. Please read the following guide to create and register a MOK:"
            echo "https://rpmfusion.org/Howto/Secure%20Boot?highlight=%28%5CbCategoryHowto%5Cb%29"
            echo "Note that installing a MOK will trip Bitlocker encryption if you have it enabled in a Windows dual-boot, please make sure you have access to your recovery keys: https://aka.ms/myrecoverykey"
            echo "Or you can disable secure boot."
            exit 3
        fi

        # sign modules
        echo "Signing modules..."
        "/usr/src/kernels/$(uname -r)/scripts/sign-file" sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der "$(modinfo -n vmnet)"
        "/usr/src/kernels/$(uname -r)/scripts/sign-file" sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der "$(modinfo -n vmmon)"

        echo "Loading modules..."
        modprobe vmmon vmnet
    else
        echo "Could not load modules (secure boot disabled)" && exit 2
    fi
fi

systemctl restart vmware.service vmware-USBArbitrator.service

exit 0
