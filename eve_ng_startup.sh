#!/bin/bash
set -e

# Update and install dependencies
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install -y software-properties-common

# Add EVE-NG repository
add-apt-repository universe
add-apt-repository multiverse
add-apt-repository restricted

# Basic dependencies for EVE-NG
apt install -y git wget curl nano unzip bridge-utils qemu-kvm \
 libvirt-daemon-system libvirt-clients virtinst cpu-checker \
 libguestfs-tools python3 python3-pip genisoimage

# Download EVE-NG Community ISO and mount (placeholder step)
# You would typically mount and install or use a premade script

# Placeholder for further setup
echo "EVE-NG base dependencies installed. Manual install steps may still be required."

# Optional reboot
# reboot
