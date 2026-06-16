provider "google" {
  credentials = base64decode(var.google_credentials_b64)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

resource "google_compute_instance" "eve_ng" {
  name         = "eve-ng-vm"
  machine_type = "n2-standard-8"
  zone         = var.zone

  boot_disk {
    auto_delete = true
    initialize_params {
      image = "nested-ubuntu-jammy"
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  # NOTE: added "eve-ng" so the firewall rule (target_tags = ["eve-ng"])
  # actually binds to this VM. Previously it did not.
  tags = ["allow-ssh", "allow-http", "allow-https", "eve-ng"]

  metadata = {
    # Provisions theme + Duo MFA gateway on boot by pulling this repo.
    startup-script    = file("${path.module}/provisioning/bootstrap.sh")
    gateway-secret    = var.gateway_secret_key
    duo-client-id     = var.duo_client_id
    duo-client-secret = var.duo_client_secret
    duo-api-host      = var.duo_api_host
    server-name       = var.server_name
    letsencrypt-email = var.letsencrypt_email
    enable-letsencrypt = tostring(var.enable_letsencrypt)
  }

  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = false
    enable_integrity_monitoring = false
  }
}
