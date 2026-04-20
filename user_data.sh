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

# Install Tailscale (idempotent)
if ! command -v tailscale &> /dev/null; then
  echo "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
else
  echo "Tailscale already installed, skipping installation"
fi

if [ -n "$TAILSCALE_AUTH_KEY" ]; then
  # Only authenticate if not already authenticated
  if ! tailscale status &> /dev/null | grep -q "Logged in"; then
    echo "Authenticating with Tailscale..."
    tailscale up \
      --authkey="$TAILSCALE_AUTH_KEY" \
      --hostname="$VM_NAME" \
      --accept-dns=false \
      --advertise-exit-node
  else
    echo "Tailscale already authenticated, skipping"
  fi
else
  echo "WARNING: No Tailscale auth key provided. Run 'tailscale up' manually."
fi

# Install Cloudflare Tunnel (cloudflared) (idempotent)
if ! command -v cloudflared &> /dev/null; then
  echo "Installing Cloudflare Tunnel (cloudflared)..."
  curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  dpkg -i cloudflared.deb
  rm cloudflared.deb
else
  echo "Cloudflare Tunnel already installed, skipping installation"
fi

if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
  # Create cloudflared config directory if it doesn't exist
  if [ ! -d /etc/cloudflared ]; then
    echo "Setting up Cloudflare Tunnel..."
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
  else
    echo "Cloudflare Tunnel already configured, skipping setup"
  fi
else
  echo "WARNING: No Cloudflare token provided. Tunnel setup skipped."
fi

# Install Docker (idempotent)
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  usermod -aG docker azureuser
else
  echo "Docker already installed, skipping installation"
fi

# Install K3s (idempotent)
if ! command -v k3s &> /dev/null; then
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
else
  echo "K3s already installed, skipping installation"
fi

# Copy/update kubeconfig for veverkap user (always run this)
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  mkdir -p /home/veverkap/.kube
  cp /etc/rancher/k3s/k3s.yaml /home/veverkap/.kube/config
  sed -i "s/127.0.0.1/$VM_NAME/g" /home/veverkap/.kube/config
  chown -R veverkap:veverkap /home/veverkap/.kube
  chmod 600 /home/veverkap/.kube/config
  echo "✅ kubeconfig updated at /home/veverkap/.kube/config"
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
