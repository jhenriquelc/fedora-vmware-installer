#!/usr/bin/bash

orig=`pwd`
temp=/tmp/fedora-vmware-installer/

sudo dnf update
sudo dnf install kernel-devel kernel-headers gcc gcc-c++ make git

mkdir $temp
cd $temp
wget --user-agent="Mozilla" --content-disposition "https://www.vmware.com/go/getplayer-linux"

chmod +x VMware*.bundle
sudo ./VMware*.bundle
VMWARE_VERSION=$(cat /etc/vmware/config | grep player.product.version | sed '/.*\"\(.*\)\".*/ s//\1/g')

git clone -b workstation-${VMWARE_VERSION} https://github.com/mkubecek/vmware-host-modules.git

cd vmware-host-modules/
make
sudo make install

sudo cp $orig/99-vmmodules.install /etc/kernel/install.d/
sudo chmod +x /etc/kernel/install.d/99-vmmodules.install

if mokutil --sb-state | grep -q "SecureBoot enabled" ; then
	if [[ -f "/etc/pki/akmods/private/private_key.priv" ]] ; then
		echo "Assinando módulos para secure boot..."
		sudo /usr/src/kernels/`uname -r`/scripts/sign-file sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der $(modinfo -n vmmon)
		sudo /usr/src/kernels/`uname -r`/scripts/sign-file sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der $(modinfo -n vmnet)
	else
		echo "You're using secure boot but don't seem to have a self-signing key present. Please read the following guide to create and register a MOK:"
		echo "https://rpmfusion.org/Howto/Secure%20Boot?highlight=%28%5CbCategoryHowto%5Cb%29"
		echo "Or you can disable secure boot."
	fi
	
	echo "You're using secure boot, you'll need to sign your keys every kernel update with the following commands:"
	echo "sudo /usr/src/kernels/`uname -r`/scripts/sign-file sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der $(modinfo -n vmmon)"
	echo "sudo /usr/src/kernels/`uname -r`/scripts/sign-file sha256 /etc/pki/akmods/private/private_key.priv /etc/pki/akmods/certs/public_key.der $(modinfo -n vmnet)"
fi
sudo modprobe vmmon
sudo modprobe vmnet

