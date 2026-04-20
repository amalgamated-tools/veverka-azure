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
    --accept-dns=false \
    --advertise-exit-node
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

# Install K3s
echo "Installing K3s..."
K3S_NODE_NAME="$VM_NAME" K3S_URL="${k3s_url}" K3S_TOKEN="${k3s_token}" curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
for i in {1..30}; do
  if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    echo "K3s is ready"
    break
  fi
  echo "Waiting... ($i/30)"
  sleep 5
done

# Copy kubeconfig for veverkap user
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  mkdir -p /home/veverkap/.kube
  cp /etc/rancher/k3s/k3s.yaml /home/veverkap/.kube/config
  sed -i "s/127.0.0.1/$VM_NAME/g" /home/veverkap/.kube/config
  chown -R veverkap:veverkap /home/veverkap/.kube
  chmod 600 /home/veverkap/.kube/config
  echo "✅ kubeconfig copied to /home/veverkap/.kube/config"
fi

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
echo ""
echo "K3s Status:"
/usr/local/bin/k3s -v || echo "K3s not yet installed"
