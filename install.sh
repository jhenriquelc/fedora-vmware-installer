#!/usr/bin/bash

set -e

function yes-or-no {
    while true; do
        read -r -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;
            [Nn]*) return  1 ;;
        esac
    done
}

if [ $UID -ne 0 ]; then
    echo "script must be invoked as root."
    exit 1
fi

if [[ -f "/etc/kernel/install.d/99-vmmodules.install" ]] ; then # old version installed
    echo "Old reinstall script detected at '/etc/kernel/install.d/99-vmmodules.install'"
    if yes-or-no "Would you like to delete it?" ; then
        rm /etc/kernel/install.d/99-vmmodules.install
    fi
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

pushd . > /dev/null
cd /opt

    if [[ -e vm-host-modules ]] ; then
        echo "Modules source code folder detected at '/opt/vm-host-modules'. Continuing with installation will replace the folder, potentially causing data loss."
        if yes-or-no "Continue? (replace folder)" ; then
            rm -rf /opt/vm-host-modules
        else
            echo "Aborting..."
            exit 2
        fi
    fi

    git clone -b 17.6 https://github.com/bytium/vm-host-modules
    cd vm-host-modules/

    make
    make install
    make clean

popd > /dev/null

cp reinstall.sh /opt/vm-host-modules/
chmod +x /opt/vm-host-modules/reinstall.sh

cp vm-host-modules-reinstall.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable vm-host-modules-reinstall.service

if mokutil --sb-state | grep -q "SecureBoot enabled" ; then
    if [[ -f "/etc/pki/akmods/private/private_key.priv" ]] ; then
        echo "Signing modules for SecureBoot..."
        sudo "/usr/src/kernels/$(uname -r)/scripts/sign-file" sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der $(modinfo -n vmmon)
        sudo "/usr/src/kernels/$(uname -r)/scripts/sign-file" sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der $(modinfo -n vmnet)
    fi
fi

modprobe vmmon
modprobe vmnet
systemctl restart vmware.service vmware-USBArbitrator.service
