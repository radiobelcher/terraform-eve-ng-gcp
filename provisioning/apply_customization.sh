#!/bin/bash
#
# Idempotent installer: black/orange theme + Duo MFA gateway + nginx front.
# Safe to re-run. Intended to run as root on the EVE-NG box, either from the
# Terraform startup-script (bootstrap.sh) or by hand after an `ssh` in.
#
# Reads Duo/secret config from the environment (bootstrap.sh exports these
# from instance metadata). If run by hand, source an env file first.
#
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROV="$REPO_DIR/provisioning"
log() { echo "[apply] $*"; }

: "${GATEWAY_SECRET_KEY:?set GATEWAY_SECRET_KEY}"
: "${DUO_CLIENT_ID:?set DUO_CLIENT_ID}"
: "${DUO_CLIENT_SECRET:?set DUO_CLIENT_SECRET}"
: "${DUO_API_HOST:?set DUO_API_HOST}"
: "${SERVER_NAME:=lab.radiobelcher.com}"

EVE_THEME_DIR="/opt/unetlab/html/themes/adminLTE/unl_data/css"

# --- 1. Packages ----------------------------------------------------------
log "installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx python3-venv python3-pip openssl

# --- 2. Black/orange EVE dashboard theme ----------------------------------
if [ -d "$EVE_THEME_DIR" ]; then
  log "applying EVE theme override"
  [ -f "$EVE_THEME_DIR/custom_unl.css" ] && [ ! -f "$EVE_THEME_DIR/custom_unl.css.bak" ] \
      && cp "$EVE_THEME_DIR/custom_unl.css" "$EVE_THEME_DIR/custom_unl.css.bak"
  install -m 0644 "$PROV/theme/custom_unl.css" "$EVE_THEME_DIR/custom_unl.css"
else
  log "WARN: EVE theme dir not found ($EVE_THEME_DIR) — skipping dashboard theme"
fi

# --- 3. Duo gateway service ----------------------------------------------
log "installing Duo gateway"
id duogw &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin duogw
mkdir -p /opt/duo-gateway /etc/duo-gateway /var/log/duo-gateway
cp -r "$PROV/duo-gateway/." /opt/duo-gateway/
if [ ! -d /opt/duo-gateway/venv ]; then
  python3 -m venv /opt/duo-gateway/venv
fi
/opt/duo-gateway/venv/bin/pip install --quiet --upgrade pip
/opt/duo-gateway/venv/bin/pip install --quiet -r /opt/duo-gateway/requirements.txt
chown -R duogw:duogw /opt/duo-gateway /var/log/duo-gateway

umask 077
cat > /etc/duo-gateway/gateway.env <<EOF
GATEWAY_SECRET_KEY=${GATEWAY_SECRET_KEY}
DUO_CLIENT_ID=${DUO_CLIENT_ID}
DUO_CLIENT_SECRET=${DUO_CLIENT_SECRET}
DUO_API_HOST=${DUO_API_HOST}
SERVER_NAME=${SERVER_NAME}
EVE_UPSTREAM=http://127.0.0.1:80
SESSION_TTL=28800
EOF
chown duogw:duogw /etc/duo-gateway/gateway.env
chmod 600 /etc/duo-gateway/gateway.env

install -m 0644 "$PROV/duo-gateway/duo-gateway.service" /etc/systemd/system/duo-gateway.service
systemctl daemon-reload
systemctl enable duo-gateway
systemctl restart duo-gateway

# --- 4. TLS: self-signed bootstrap so nginx can start --------------------
# nginx always points at /etc/ssl/eve/*; we swap in the real Let's Encrypt
# cert in step 7 and keep these paths stable across renewals.
mkdir -p /etc/ssl/eve /var/www/certbot
if [ ! -f /etc/ssl/eve/fullchain.pem ]; then
  log "generating bootstrap self-signed cert"
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout /etc/ssl/eve/privkey.pem -out /etc/ssl/eve/fullchain.pem \
    -subj "/CN=${SERVER_NAME}"
fi

# --- 5. Bind Apache to localhost only (close the bypass) -----------------
log "binding Apache to 127.0.0.1"
if [ -f /etc/apache2/ports.conf ]; then
  cp -n /etc/apache2/ports.conf /etc/apache2/ports.conf.bak
  sed -i -E 's/^\s*Listen\s+(0\.0\.0\.0:)?80\s*$/Listen 127.0.0.1:80/' /etc/apache2/ports.conf
  # Disable Apache's own public 443 vhost; nginx owns 443 now.
  sed -i -E 's/^\s*Listen\s+(0\.0\.0\.0:)?443/#&  # disabled: nginx fronts 443/' /etc/apache2/ports.conf
  a2dissite default-ssl 000-default-ssl 2>/dev/null || true
  systemctl reload apache2 || systemctl restart apache2 || true
fi

# --- 6. nginx front -------------------------------------------------------
log "installing nginx site"
install -m 0644 "$PROV/nginx/lab.radiobelcher.com.conf" /etc/nginx/sites-available/lab.radiobelcher.com.conf
ln -sf /etc/nginx/sites-available/lab.radiobelcher.com.conf /etc/nginx/sites-enabled/lab.radiobelcher.com.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx

# --- 7. Real cert via Let's Encrypt --------------------------------------
# Requires: DNS ${SERVER_NAME} -> this VM, port 80 reachable. Idempotent.
if [ "${ENABLE_LETSENCRYPT:-true}" = "true" ]; then
  log "provisioning Let's Encrypt cert for ${SERVER_NAME}"
  apt-get install -y certbot

  # Renewal deploy-hook: copy renewed cert into the stable path nginx uses.
  cat > /etc/letsencrypt/renewal-hooks/deploy/10-sync-eve.sh <<HOOK
#!/bin/bash
cp -L /etc/letsencrypt/live/${SERVER_NAME}/fullchain.pem /etc/ssl/eve/fullchain.pem
cp -L /etc/letsencrypt/live/${SERVER_NAME}/privkey.pem  /etc/ssl/eve/privkey.pem
systemctl reload nginx
HOOK
  chmod +x /etc/letsencrypt/renewal-hooks/deploy/10-sync-eve.sh

  if [ ! -d "/etc/letsencrypt/live/${SERVER_NAME}" ]; then
    if certbot certonly --webroot -w /var/www/certbot \
         -d "${SERVER_NAME}" --non-interactive --agree-tos \
         -m "${LETSENCRYPT_EMAIL:-radiobelcher@gmail.com}"; then
      /etc/letsencrypt/renewal-hooks/deploy/10-sync-eve.sh
      log "Let's Encrypt cert installed"
    else
      log "WARN: certbot failed — staying on self-signed cert (check DNS/port 80)"
    fi
  else
    # Cert already exists (e.g. re-run): make sure nginx has the current copy.
    /etc/letsencrypt/renewal-hooks/deploy/10-sync-eve.sh
  fi
fi

log "done. Visit https://${SERVER_NAME}/ — you should be redirected to the Duo gateway login."
