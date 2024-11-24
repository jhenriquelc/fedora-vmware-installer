# VMware Workstation kernel modules installer for Fedora

This script installs VMware Workstation, including modified kernel modules and a script to automatically build them for future kernel updates.

Currently made for Fedora 41 and VMware Workstation 17.6.
This software is provided *as-is*, proceed at your own risk.
Please [read the source](https://github.com/jhenriquelc/fedora-vmware-installer/blob/main/install.sh) to see what it does before you run it.

[Modified kernel modules from Bytium](https://github.com/bytium/vm-host-modules)

## Secure Boot

This tool uses the same keys used by akmods for signing modules (such as the RPM Fusion NVIDIA proprietary drivers) so they're able to be loaded with secure boot enabled.

You can check if your system has secure boot enabled by running the following command:

```bash
mokutil --sb-state
```

If secure boot is disabled, you can skip this section.

To verify if the akmods key is present and trusted, use this little script (that shoud be run as root because the key file is protected):

```bash
if [[ -f "/etc/pki/akmods/private/private_key.priv" ]]; then
	echo "akmods MOK is present."
	echo "MOK enrollment status:"
	mokutil --test-key /etc/pki/akmods/certs/public_key.der
else
	echo "akmods MOK is unavailable."
fi
```

If the key is not present or it is not enrolled, please follow the [RPM Fusion secure boot how-to](https://rpmfusion.org/Howto/Secure%20Boot?highlight=%28%5CbCategoryHowto%5Cb%29).

> [!WARNING]
> **Enrolling a new MOK will trip Bitlocker encryption** if you have it enabled in a Windows dual-boot. Make sure you have access to [your recovery keys](https://support.microsoft.com/en-us/windows/find-your-bitlocker-recovery-key-6b71ad27-0b89-ea08-f143-056f5ab347d6).

The script will prevent you from installing if you have secure boot enabled but don't have a MOK available.

## Usage

To use the script, run the following commands:

```bash
# after having installed VMware
git clone https://github.com/jhenriquelc/fedora-vmware-installer.git
cd fedora-vmware-installer
sudo ./install.sh
```

## Uninstall

To uninstall the modules' reinstaller script:

- Delete the service at `/etc/systemd/system/vm-host-modules-reinstall.service`.
- Delete the modules source folder and reinstall script at `/opt/vm-host-modules`.
