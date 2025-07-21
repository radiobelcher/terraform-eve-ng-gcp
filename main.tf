provider "google" {
  credentials = base64decode(var.google_credentials_b64)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}


resource "google_compute_instance" "eve_ng" {
  name         = "eve-ng-vm"
  machine_type = "n2-standard-16"
  zone         = var.zone
  metadata_startup_script = file("eve_ng_startup.sh")


  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 200
      type  = "pd-ssd"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  tags = ["http-server", "https-server", "eve-ng"]
}


resource "google_compute_instance" "eve_ng" {
  name         = "eve-ng-vm"
  machine_type = "n2-standard-16"
  zone         = var.zone

  metadata_startup_script = file("eve_ng_startup_autoinstall.sh")

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 200
      type  = "pd-ssd"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  tags = ["http-server", "https-server", "eve-ng"]
}
