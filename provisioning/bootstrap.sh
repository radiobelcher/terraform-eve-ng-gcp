#!/bin/bash
#
# Terraform metadata_startup_script entrypoint.
# Pulls this repo from GitHub and runs the idempotent customization installer.
# Secrets are read from instance metadata (set by Terraform), never baked in.
#
set -euo pipefail
REPO_URL="https://github.com/radiobelcher/terraform-eve-ng-gcp.git"
DEST="/opt/eve-custom"
MD="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
mdget() { curl -s -H "Metadata-Flavor: Google" "$MD/$1"; }

export DEBIAN_FRONTEND=noninteractive
command -v git >/dev/null || { apt-get update -y && apt-get install -y git curl; }

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull --ff-only
else
  git clone --depth 1 "$REPO_URL" "$DEST"
fi

export GATEWAY_SECRET_KEY="$(mdget gateway-secret)"
export DUO_CLIENT_ID="$(mdget duo-client-id)"
export DUO_CLIENT_SECRET="$(mdget duo-client-secret)"
export DUO_API_HOST="$(mdget duo-api-host)"
export SERVER_NAME="$(mdget server-name)"
export LETSENCRYPT_EMAIL="$(mdget letsencrypt-email)"
export ENABLE_LETSENCRYPT="$(mdget enable-letsencrypt)"

bash "$DEST/provisioning/apply_customization.sh"
