#!/bin/bash

# Load environment variables if present
if [ -f .env ]; then
  source .env
fi

# Prompt for Contabo API credentials if not present in .env
if [ -z "$CONTABO_CLIENT_ID" ]; then
  read -p "Enter your Contabo API Client ID: " CONTABO_CLIENT_ID
  echo "CONTABO_CLIENT_ID=$CONTABO_CLIENT_ID" >> .env
fi

if [ -z "$CONTABO_CLIENT_SECRET" ]; then
  read -p "Enter your Contabo API Client Secret: " CONTABO_CLIENT_SECRET
  echo "CONTABO_CLIENT_SECRET=$CONTABO_CLIENT_SECRET" >> .env
fi

if [ -z "$CONTABO_USERNAME" ]; then
  read -p "Enter your Contabo API Username: " CONTABO_USERNAME
  echo "CONTABO_USERNAME=$CONTABO_USERNAME" >> .env
fi

if [ -z "$CONTABO_PASSWORD" ]; then
  read -sp "Enter your Contabo API Password: " CONTABO_PASSWORD
  echo
  echo "CONTABO_PASSWORD=$CONTABO_PASSWORD" >> .env
fi

# Prompt for Mullvad account number
read -p "Enter your Mullvad account number (needed for VPN setup): " MULLVAD_ACCOUNT
if [ -z "$MULLVAD_ACCOUNT" ]; then
  echo "Warning: No Mullvad account number provided. VPN functionality will be limited."
else
  echo "MULLVAD_ACCOUNT=$MULLVAD_ACCOUNT" >> .env
fi

# Generate SSH key if it doesn't exist
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "Generating SSH key at $SSH_KEY_PATH..."
  ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
fi

# Initialize and apply Terraform configuration
echo "Initializing Terraform..."
terraform init

echo "Applying Terraform configuration..."
terraform apply -auto-approve

# Get server IP
SERVER_IP=$(terraform output -raw server_ip)

# Create dynamic Ansible inventory
echo "Creating Ansible inventory with server IP: $SERVER_IP..."
sed "s/{{ server_ip }}/$SERVER_IP/g" inventory/hosts.yml.template > inventory/hosts.yml

# Create extra vars file for Mullvad configuration
cat > inventory/group_vars/mullvad_vars.yml << EOF
---
mullvad_account: "$MULLVAD_ACCOUNT"
EOF

# Wait for SSH to become available
echo "Waiting for server to be ready..."
until ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH -o ConnectTimeout=5 root@${SERVER_IP} 'exit'; do
  echo "Retrying connection in 5 seconds..."
  sleep 5
done

# Run Ansible playbook
echo "Running Ansible playbook..."
ansible-playbook playbooks/site.yml

echo "====================================="
echo "OSINT Server deployed at ${SERVER_IP}"
echo "Connect with: ssh -i $SSH_KEY_PATH root@${SERVER_IP}"
echo "Or through the mobile interface: ssh -i $SSH_KEY_PATH user@${SERVER_IP}"
echo "Check campo_credentials.txt for the campo user password"
echo ""
echo "IMPORTANT SECURITY NOTICE:"
echo "1. The credentials file 'campo_credentials.txt' contains sensitive information"
echo "2. After saving these credentials securely, delete this file with:"
echo "   $ shred -u campo_credentials.txt    # Linux/macOS with shred"
echo "   $ srm campo_credentials.txt         # macOS with srm"
echo "   For Windows, use a secure deletion tool like Eraser or BleachBit"
echo "====================================="
