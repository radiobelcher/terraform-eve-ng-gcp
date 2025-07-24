# main.tf
provider "google" {
  credentials = base64decode(var.google_credentials_b64)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

resource "google_compute_instance" "eve_ng" {
  name         = "eve-ng-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.custom_image_name
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  tags = ["allow-ssh", "allow-http", "allow-https"]
}

resource "google_compute_firewall" "allow_external" {
  name    = "allow-ssh-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh", "allow-http", "allow-https"]
}
