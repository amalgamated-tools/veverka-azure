# Veverka Azure Infrastructure

Terraform configuration for 3 x B2s v2 Azure VMs running nanobot, Honcho, and secondary services.

## Quick Start

```bash
# Initialize Terraform
terraform init

# See what will be created (3 VMs: VAZURE1, VAZURE2, VAZURE3)
terraform plan

# Deploy the infrastructure
terraform apply

# Get outputs
terraform output vm_public_ips
terraform output vm_private_ips

# Destroy everything (careful!)
terraform destroy
```

## Tailscale & Cloudflare Tunnel Setup

### Getting Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Generate a new **Reusable** auth key (with expiry if desired)
3. Copy the key and use it when deploying

### Getting Cloudflare Tunnel Token

1. Go to https://dash.cloudflare.com/
2. Navigate to **Zero Trust** → **Networks** → **Tunnels**
3. Create a new tunnel or use existing one
4. Copy the **installation token**

### Deploying with Tailscale & Cloudflare

```bash
terraform apply \
  -var="tailscale_auth_key=tskey-xxxxxxxxxxxxxxxx" \
  -var="cloudflare_tunnel_token=xxxxxxxx"
```

Or add to `terraform.tfvars`:

```hcl
tailscale_auth_key       = "tskey-xxxxxxxxxxxxxxxx"
cloudflare_tunnel_token  = "xxxxxxxx"
```

### Manual Cloudflare Setup (if needed)

After VMs are created, SSH into each and run:

```bash
sudo cloudflared service install <TOKEN>
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

### Verify Setup

```bash
# Check Tailscale
sudo tailscale status

# Check Cloudflared
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -n 50
```

## Infrastructure

- **3x B2s v2 VMs** (2 vCPU, 8GB RAM each)
- **Location**: East US (cheapest region)
- **Networking**: VNet, subnet, NSG with SSH inbound
- **Storage**: Premium SSD managed disks
- **Free tier**: 750 hours/month per VM (12 months)

## VM Names

- **VAZURE1** — nanobot gateway + copilot-api
- **VAZURE2** — Honcho + PostgreSQL + Redis
- **VAZURE3** — Secondary services (n8n, Qdrant, etc.)

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

