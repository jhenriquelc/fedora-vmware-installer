#!/usr/bin/bash

set -e

function yes-or-no() {
    while true; do
        read -r -p "$* [y/n]: " yn
        case $yn in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        esac
    done
}

if [ $UID -ne 0 ]; then
    echo "script must be invoked as root."
    exit 1
fi

# Remove old reinstallation script
echo "Checking for old reinstallation script..."
if [[ -f "/etc/kernel/install.d/99-vmmodules.install" ]]; then
    echo "Old reinstall script detected at '/etc/kernel/install.d/99-vmmodules.install'"
    if yes-or-no "Would you like to delete it?"; then
        rm /etc/kernel/install.d/99-vmmodules.install
    fi
fi

# SecureBoot check
echo "Checking SecureBoot and MOK status..."
if mokutil --sb-state | grep -q "SecureBoot enabled"; then
    if [[ ! -f "/etc/pki/akmods/private/private_key.priv" ]]; then
        echo "You're using secure boot but don't seem to have a self-signing key present. Please read the following guide to create and register a MOK:"
        echo "https://rpmfusion.org/Howto/Secure%20Boot?highlight=%28%5CbCategoryHowto%5Cb%29"
        echo "Note that installing a MOK will trip Bitlocker encryption if you have it enabled in a Windows dual-boot, please make sure you have access to your recovery keys: https://aka.ms/myrecoverykey"
        echo "Or you can disable secure boot."
        exit 3
    fi
fi

# Install dependencies
echo "Upgrade OS and install dependencies..."
dnf update --refresh
dnf install kernel-devel kernel-headers gcc gcc-c++ make git

# Clone modules source code
pushd . >/dev/null
cd /opt
echo "Checking for current installation at '/opt/vm-host-modules'..."
if [[ -e vm-host-modules ]]; then
    echo "Modules source code folder detected at '/opt/vm-host-modules'. Continuing with installation will replace the folder, potentially causing data loss."
    if yes-or-no "Continue? (replace folder)"; then
        rm -rf /opt/vm-host-modules
    else
        echo "Aborting..."
        exit 2
    fi
fi

echo "Cloning modified kernel modules source code..."
git clone -b 17.6 https://github.com/bytium/vm-host-modules
cd vm-host-modules/

echo "Building..."
make

echo "Installing..."
make install || true # Fails if SecureBoot is enabled when attempting to restart VMware's services

echo "Cleaning build directory..."
make clean

echo "Returning to installation directory"
popd >/dev/null

# Install reinstallation script
echo "Installing reinstallation script for the service..."
cp reinstall.sh /opt/vm-host-modules/
chmod +x /opt/vm-host-modules/reinstall.sh

# Install service
echo "Installing automatic reinstallation service..."
cp vm-host-modules-reinstall.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable vm-host-modules-reinstall.service

# Sign modules if needed
if mokutil --sb-state | grep -q "SecureBoot enabled"; then
    if [[ -f "/etc/pki/akmods/private/private_key.priv" ]]; then
        echo "Signing modules for SecureBoot..."
        sudo "/usr/src/kernels/$(uname -r)/scripts/sign-file" sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der "$(modinfo -n vmmon)"
        sudo "/usr/src/kernels/$(uname -r)/scripts/sign-file" sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der "$(modinfo -n vmnet)"
    fi
fi

# Start VMware services with modules present
echo "Attempting to reload installed modules"
modprobe vmmon
modprobe vmnet

echo "Restarting VMware's services..."
systemctl restart vmware.service vmware-USBArbitrator.service
