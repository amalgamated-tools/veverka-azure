#!/bin/bash
set -e

# VM Configuration
VM_NAME="${vm_name}"
TAILSCALE_AUTH_KEY="${tailscale_auth_key}"
CLOUDFLARE_TUNNEL_TOKEN="${cloudflare_tunnel_token}"

# Logging
exec > >(tee -a /var/log/user_data.log)
exec 2>&1
echo "Starting user_data script on $(date)"

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install basic tools
echo "Installing basic tools..."
apt-get install -y curl wget git unzip htop net-tools

# Install Tailscale
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

if [ -n "$TAILSCALE_AUTH_KEY" ]; then
  echo "Authenticating with Tailscale..."
  tailscale up \
    --authkey="$TAILSCALE_AUTH_KEY" \
    --hostname="$VM_NAME" \
    --accept-dns=false
else
  echo "WARNING: No Tailscale auth key provided. Run 'tailscale up' manually."
fi

# Install Cloudflare Tunnel (cloudflared)
echo "Installing Cloudflare Tunnel (cloudflared)..."
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb
rm cloudflared.deb

if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
  echo "Setting up Cloudflare Tunnel..."
  
  # Create cloudflared config directory
  mkdir -p /etc/cloudflared
  
  # Store the tunnel token (in production, use a secrets manager)
  echo "$CLOUDFLARE_TUNNEL_TOKEN" > /etc/cloudflared/token
  chmod 600 /etc/cloudflared/token
  
  # Create a basic cloudflared config
  cat > /etc/cloudflared/config.yml << 'EOF'
tunnel: veverka-azure
credentials-file: /etc/cloudflared/credentials.json
protocol: http2
logpixel: true

ingress:
  - hostname: "$VM_NAME.veverka.net"
    service: http://localhost:80
  - service: http_status:404
EOF
  
  echo "WARNING: Manual Cloudflare Tunnel setup required. See instructions below."
else
  echo "WARNING: No Cloudflare token provided. Tunnel setup skipped."
fi

# Install Docker (optional, useful for running services)
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker azureuser

# Setup system logging
echo "Setting up system logging..."
journalctl --vacuum-time=30d

# Final status
echo "User data script completed on $(date)"
echo "VM Name: $VM_NAME"
echo "Tailscale Status:"
tailscale status || echo "Tailscale not yet authenticated"
echo ""
echo "Cloudflared Status:"
systemctl status cloudflared --no-pager || echo "Cloudflared not yet configured"
