#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Update and upgrade the system
apt update && apt upgrade -y

# Add required repositories
add-apt-repository universe -y
add-apt-repository multiverse -y
add-apt-repository restricted -y

# Install dependencies
apt install -y wget nano software-properties-common aptitude \
 qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
 virtinst cpu-checker genisoimage libguestfs-tools unzip git \
 curl python3 python3-pip dialog

# Disable AppArmor (EVE-NG requirement)
systemctl disable apparmor --now || true

# Download EVE-NG installation script
wget https://www.eve-ng.net/repo/install-eve.sh -O /root/install-eve.sh
chmod +x /root/install-eve.sh

# Run EVE-NG installation
/root/install-eve.sh

# Set default credentials (admin/eve)
echo "EVE-NG installation complete. Access via https://<your-vm-ip> with admin / eve"
