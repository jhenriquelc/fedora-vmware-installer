#!/usr/bin/bash

set -e

if [ $UID -ne 0 ]; then
    echo "script must be invoked as root."
    exit 1
fi

if [ ! -f $1 ]; then
    echo "$1": file not found
    echo "Please provide a VMWare Workstation 17.6 bundle as an argument."
    exit 2
fi

if mokutil --sb-state | grep -q "SecureBoot enabled" ; then
    if [[ ! -f "/etc/pki/akmods/private/private_key.priv" ]] ; then
        echo "You're using secure boot but don't seem to have a self-signing key present. Please read the following guide to create and register a MOK:"
        echo "https://rpmfusion.org/Howto/Secure%20Boot?highlight=%28%5CbCategoryHowto%5Cb%29"
        echo "Note that installing a MOK will trip Bitlocker encryption if you have it enabled in a Windows dual-boot, please make sure you have access to your recovery keys: https://aka.ms/myrecoverykey"
        echo "Or you can disable secure boot."
        exit 3
    fi
fi

dnf update --refresh
dnf install kernel-devel kernel-headers gcc gcc-c++ make git

chmod +x $1
$1

pushd .
cd /opt

    git clone -b 17.6 https://github.com/bytium/vm-host-modules
    cd vm-host-modules/

    make
    make install
    make clean

popd

cp 99-vmmodules.install /etc/kernel/install.d/
chmod +x /etc/kernel/install.d/99-vmmodules.install

if mokutil --sb-state | grep -q "SecureBoot enabled" ; then
    if [[ -f "/etc/pki/akmods/private/private_key.priv" ]] ; then
        echo "Signing modules for SecureBoot..."
        sudo /usr/src/kernels/`uname -r`/scripts/sign-file sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der $(modinfo -n vmmon)
        sudo /usr/src/kernels/`uname -r`/scripts/sign-file sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der $(modinfo -n vmnet)
    fi
fi

modprobe vmmon
modprobe vmnet
systemctl restart vmware.service vmware-USBArbitrator.service
