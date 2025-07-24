resource "google_compute_instance" "eve_ng" {
  name         = "eve-ng-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

boot_disk {
  initialize_params {
    image  = "ubuntu-os-cloud/ubuntu-2204-lts"
    size   = 40
    type   = "pd-standard"
  }
}

  network_interface {
    network = "default"

    access_config {
      # This gives the instance a public IP
    }
  }

  metadata_startup_script = file("eve_ng_startup_autoinstall.sh")  # or null if you're manually installing
}

provider "google" {
  credentials = base64decode(var.google_credentials_b64)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}
