# EVE-NG: black/orange branding + Duo MFA gateway

This adds a black-and-orange login experience and **real** two-factor auth in
front of the EVE-NG web UI, without forking EVE itself.

## How it works

```
Internet ─443─> nginx (TLS, auth gate)
                 ├─ /gw/*  → Duo gateway (Flask)         [not gated]
                 │           1. username/password verified against EVE's API
                 │           2. Duo Universal Prompt (push/passcode)
                 │           3. sets signed session + EVE unetlab_session cookie
                 └─ /*     → EVE-NG Apache @127.0.0.1   [gated by /gw/auth]
```
Apache is rebound to `127.0.0.1` so the only way in is through the gate.
HTTP/websocket upgrades are preserved, so HTML5 consoles keep working.

## 1. Create the Duo application (one time)

1. Sign in to the **Duo Admin Panel** (free tier covers up to 10 users).
2. **Applications → Protect an Application → "Web SDK"** (Duo Universal Prompt).
3. Copy the **Client ID**, **Client secret**, and **API hostname**
   (`api-XXXXXXXX.duosecurity.com`).
4. Enroll yourself as a Duo user with the **same username** you use to log into
   EVE-NG (the gateway passes that username to Duo).

> No Active Directory / Duo SSO needed — the Web SDK app is standalone.

## 2. Wire the secrets into Terraform

Set these as **sensitive** variables (Terraform Cloud workspace vars, or
`TF_VAR_*` env — never commit them):

| Variable | Value |
|---|---|
| `gateway_secret_key` | `openssl rand -hex 32` |
| `duo_client_id`      | from Duo |
| `duo_client_secret`  | from Duo (sensitive) |
| `duo_api_host`       | from Duo |
| `server_name`        | `lab.radiobelcher.com` |

## 3. Deploy

**Recommended — validate on a throwaway instance first**, because the apply
script reconfigures Apache/nginx on the box:

```bash
terraform plan      # confirm the eve-ng tag + metadata + startup-script changes
terraform apply
```

On boot the VM pulls this repo and runs `provisioning/bootstrap.sh`
→ `apply_customization.sh`, which installs the theme, the Duo gateway, and
nginx, then rebinds Apache to localhost.

### Applying to the EXISTING live box

Changing `metadata_startup_script` does **not** re-run it on a running VM.
For the box that's already up, either:

* **Re-run the startup script** (no rebuild):
  ```bash
  gcloud compute ssh eve-ng-vm --zone=us-central1-a --command \
    'sudo google_metadata_script_runner startup'
  ```
* **Or run the installer directly** over SSH after exporting the env vars:
  ```bash
  sudo GATEWAY_SECRET_KEY=... DUO_CLIENT_ID=... DUO_CLIENT_SECRET=... \
       DUO_API_HOST=... SERVER_NAME=lab.radiobelcher.com \
       bash /opt/eve-custom/provisioning/apply_customization.sh
  ```

## 4. Verify

* `https://lab.radiobelcher.com/` → redirects to the black/orange `/gw/login`.
* Enter EVE credentials → Duo push/passcode → land in EVE, no second login.
* `curl -I http://<vm-ip>/` from outside should now fail/redirect (Apache is
  localhost-only; nothing bypasses Duo).

## Notes / hardening

* **TLS:** the live box currently serves EVE's stock **self-signed** cert
  (`CN=eve-ng-vm.radiobelcher.com`, doesn't match `lab.…`). The installer
  starts nginx on a self-signed placeholder, then runs **certbot** (webroot,
  HTTP-01) to obtain a trusted **Let's Encrypt** cert for `lab.radiobelcher.com`
  and syncs it to `/etc/ssl/eve/*`. Renewal is automatic via a deploy-hook that
  re-copies the cert and reloads nginx. Needs DNS → the VM and port 80 reachable
  (both already true). Set `enable_letsencrypt = false` to stay on self-signed.
* **Secrets in metadata:** for stronger isolation, move them to GCP Secret
  Manager and have `bootstrap.sh` fetch from there instead of instance metadata.
* **Rollback:** originals are saved as `*.bak` (theme, `ports.conf`). Disable the
  gate by `systemctl stop nginx && systemctl start apache2` after restoring
  `ports.conf`.
* **EVE upgrades** overwrite `custom_unl.css` — re-run the installer to reapply.
