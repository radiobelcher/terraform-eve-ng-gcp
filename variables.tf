variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "google_credentials_b64" {
  description = "Base64-encoded GCP credentials JSON"
  type        = string
}

variable "custom_image_name" {
  description = "Custom boot image name"
  type        = string
  default     = "nested-ubuntu-jammy"
}

# ---- Duo MFA gateway -----------------------------------------------------

variable "server_name" {
  description = "Public hostname for the EVE-NG site (must match cert + Duo redirect URI)"
  type        = string
  default     = "lab.radiobelcher.com"
}

variable "gateway_secret_key" {
  description = "Random secret used to sign gateway session cookies (openssl rand -hex 32)"
  type        = string
  sensitive   = true
}

variable "duo_client_id" {
  description = "Duo Web SDK application Client ID"
  type        = string
  sensitive   = true
}

variable "duo_client_secret" {
  description = "Duo Web SDK application Client Secret"
  type        = string
  sensitive   = true
}

variable "duo_api_host" {
  description = "Duo API hostname, e.g. api-XXXXXXXX.duosecurity.com"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt registration / expiry notices"
  type        = string
  default     = "radiobelcher@gmail.com"
}

variable "enable_letsencrypt" {
  description = "Issue a trusted Let's Encrypt cert (needs DNS + port 80). If false, stays on self-signed."
  type        = bool
  default     = true
}
