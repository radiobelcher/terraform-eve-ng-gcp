resource "google_compute_firewall" "allow_ssh_http_https" {
  name    = "allow-ssh-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["eve-ng"]

  description = "Allow HTTP and HTTPS traffic to EVE-NG instances (SSH handled separately)"
}

# Allow SSH only from the trusted admin IP. Priority 900 places it ahead of
# the deny rule below so this allow is evaluated first.
resource "google_compute_firewall" "allow_ssh_admin" {
  name      = "allow-ssh-admin"
  network   = "default"
  direction = "INGRESS"
  priority  = 900

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["108.211.12.65/32"]
  target_tags   = ["allow-ssh"]

  description = "Allow SSH only from the trusted admin IP"
}

# Deny SSH from everywhere else. Priority 1000 beats GCP's built-in
# default-allow-ssh rule (priority 65534), closing the 0.0.0.0/0:22 hole
# that is not otherwise managed by this configuration.
resource "google_compute_firewall" "deny_ssh_all" {
  name      = "deny-ssh-all"
  network   = "default"
  direction = "INGRESS"
  priority  = 1000

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]

  description = "Deny SSH from all sources except the trusted admin IP"
}
