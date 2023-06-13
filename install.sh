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

if mokutil --sb-state | grep -q "SecureBoot enabled" && [[ -f "/etc/pki/akmods/private/private_key.priv" ]]; then
	sudo /usr/src/kernels/`uname -r`/scripts/sign-file sha256 ./private/private_key.priv ./certs/public_key.der $(modinfo -n vmmon)
	sudo /usr/src/kernels/`uname -r`/scripts/sign-file sha256 ./private/private_key.priv ./certs/public_key.der $(modinfo -n vmnet)
fi

