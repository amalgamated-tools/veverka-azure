#!/bin/bash
set -e

# Script to create veverkap user on Azure VMs
# Usage: ./setup-veverkap-user.sh <vm-ip-or-hostname>

VM_HOST="${1:-}"

if [ -z "$VM_HOST" ]; then
    echo "Usage: $0 <vm-ip-or-hostname>"
    echo ""
    echo "Examples:"
    echo "  $0 vazure1"
    echo "  $0 vazure2.tailnet.com"
    echo "  $0 10.0.1.100"
    exit 1
fi

echo "=========================================="
echo "Setting up veverkap user on: $VM_HOST"
echo "=========================================="
echo ""

# Check if we can reach the host
if ! ping -c 1 -W 2 "$VM_HOST" &> /dev/null; then
    echo "⚠️  Warning: Cannot ping $VM_HOST"
    echo "   Make sure you're on Tailscale or the host is reachable."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📝 Creating veverkap user on $VM_HOST..."
echo ""

# Create the user and add to docker + sudo groups
ssh azureuser@"$VM_HOST" << 'EOFCREATE'
set -e

echo "Creating veverkap user..."
sudo useradd -m -s /bin/bash veverkap

echo "Adding veverkap to sudo and docker groups..."
sudo usermod -aG sudo veverkap
sudo usermod -aG docker veverkap

echo "✅ User created successfully"
EOFCREATE

echo ""
read -sp "🔑 Enter password for veverkap (will be hidden): " PASSWORD
echo
read -sp "🔑 Confirm password: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "❌ Passwords do not match!"
    exit 1
fi

echo ""
echo "🔐 Setting password..."
ssh azureuser@"$VM_HOST" << EOFPASSWD
echo "veverkap:$PASSWORD" | sudo chpasswd
echo "✅ Password set"
EOFPASSWD

echo ""
echo "🔑 SSH Key Setup"
echo "================="

read -p "Upload SSH public key to veverkap? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Try to find SSH public key
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        SSH_KEY="$HOME/.ssh/id_rsa.pub"
        echo "Found: $SSH_KEY"
    elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        SSH_KEY="$HOME/.ssh/id_ed25519.pub"
        echo "Found: $SSH_KEY"
    else
        echo "No default SSH key found at ~/.ssh/"
        read -p "Enter path to SSH public key: " SSH_KEY
    fi

    if [ ! -f "$SSH_KEY" ]; then
        echo "❌ SSH key not found: $SSH_KEY"
        exit 1
    fi

    echo "Uploading SSH key..."
    ssh azureuser@"$VM_HOST" << EOFSSH
sudo mkdir -p /home/veverkap/.ssh
sudo tee /home/veverkap/.ssh/authorized_keys > /dev/null << 'EOFKEY'
$(cat "$SSH_KEY")
EOFKEY
sudo chown -R veverkap:veverkap /home/veverkap/.ssh
sudo chmod 700 /home/veverkap/.ssh
sudo chmod 600 /home/veverkap/.ssh/authorized_keys
echo "✅ SSH key uploaded"
EOFSSH

    echo "🔑 You can now SSH as: ssh veverkap@$VM_HOST"
fi

echo ""
echo "🚀 Configuring sudoers for passwordless sudo..."

# Add veverkap to sudoers for passwordless sudo
ssh azureuser@"$VM_HOST" << EOFSUDO
sudo tee /etc/sudoers.d/veverkap > /dev/null << 'EOFSUDERS'
veverkap ALL=(ALL) NOPASSWD:ALL
EOFSUDERS
sudo chmod 440 /etc/sudoers.d/veverkap
echo "✅ Sudoers configured (passwordless sudo enabled)"
EOFSUDO

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Verify access:"
echo "  ssh veverkap@$VM_HOST"
echo "  sudo whoami  # Should print: root"
echo ""
