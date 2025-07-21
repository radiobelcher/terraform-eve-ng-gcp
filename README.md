# Terraform GCP EVE-NG Deployment

This repo deploys an Ubuntu 22.04 LTS VM to GCP ready for EVE-NG installation.

## Setup Instructions

1. Replace `terraform.tfvars.example` with your actual values as `terraform.tfvars`.
2. Add your GCP credentials to Terraform Cloud as an environment variable:
   - Name: `GOOGLE_CREDENTIALS`
   - Value: contents of your service account JSON key
3. Initialize and apply:

```bash
terraform init
terraform apply
```