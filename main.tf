# main.tf
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

  tags = ["allow-ssh", "allow-http", "allow-https"]

  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = false
    enable_integrity_monitoring = true
  }
}
