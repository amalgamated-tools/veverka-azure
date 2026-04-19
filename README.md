# Veverka Azure Infrastructure

Terraform configuration for 3 x B2s v2 Azure VMs running nanobot, Honcho, and secondary services.

## Quick Start

```bash
# Initialize Terraform
terraform init

# See what will be created
terraform plan

# Deploy the infrastructure
terraform apply

# Destroy everything (careful!)
terraform destroy
```

## Infrastructure

- **3x B2s v2 VMs** (2 vCPU, 8GB RAM each)
- **Location**: East US (cheapest region)
- **Networking**: VNet, subnet, NSG with SSH inbound
- **Storage**: Premium SSD managed disks
- **Free tier**: 750 hours/month per VM (12 months)

## VM Purpose

1. **veverka-vm-1**: nanobot gateway + copilot-api
2. **veverka-vm-2**: Honcho + PostgreSQL + Redis
3. **veverka-vm-3**: Secondary services (n8n, Qdrant, etc.)

## Estimated Costs

- **During free tier (12 months)**: ~$20/month (storage only)
- **After free tier**: ~$33/month (3 VMs @ $11/month each) + storage
- **Total budget**: $120/month ✅

## Files

- `main.tf` — Resource definitions
- `variables.tf` — Input variables (vm_count, vm_size, location)
- `outputs.tf` — Output values (IPs, resource IDs)
- `terraform.tfvars` — Local variable overrides (excluded from git)

## Prerequisites

1. Azure CLI installed and authenticated: `az login`
2. Terraform installed: `brew install terraform`
3. SSH key for VM access

## **To Get Your SSH Public Key from 1Password:**

```bash
# If you have the 1Password CLI installed:
op item get "<ssh-key-name>" --format=json | jq -r '.details.publicKey'

# Or manually:
# 1. Open 1Password
# 2. Find your SSH key
# 3. Copy the public key content
```

Then create `terraform.tfvars`:

```hcl
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EA..."
```

The private key stays in 1Password — Terraform only needs the public key for the VMs.

