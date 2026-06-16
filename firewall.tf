resource "google_compute_firewall" "allow_ssh_http_https" {
  name    = "allow-ssh-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  # Matches the "eve-ng" tag now present on the instance (see main.tf).
  target_tags = ["eve-ng"]

  description = "Allow SSH, HTTP, and HTTPS traffic to EVE-NG instances"
}
