#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Switch to root user
sudo -i

# Download and run EVE-NG installer for Ubuntu 22.04 (Jammy)
wget -O - https://www.eve-ng.net/jammy/install-eve.sh | bash -i

# Update and upgrade packages
apt update && apt upgrade -y

# Reboot to complete setup
reboot
