#!/bin/bash

# Load environment variables if present
if [ -f .env ]; then
  source .env
fi

# Check for required environment variables
if [ -z "$CONTABO_CLIENT_ID" ] || [ -z "$CONTABO_CLIENT_SECRET" ] || [ -z "$CONTABO_USERNAME" ] || [ -z "$CONTABO_PASSWORD" ]; then
  echo "Error: Missing cloud provider credentials"
  echo "Please create a .env file based on .env.template"
  exit 1
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

# Wait for SSH to become available
echo "Waiting for server to be ready..."
until ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 -o ConnectTimeout=5 root@${SERVER_IP} 'exit'; do
  echo "Retrying connection in 5 seconds..."
  sleep 5
done

# Run Ansible playbook
echo "Running Ansible playbook..."
ansible-playbook playbooks/site.yml

echo "====================================="
echo "OSINT Server deployed at ${SERVER_IP}"
echo "Connect with: ssh -i ~/.ssh/id_ed25519 root@${SERVER_IP}"
echo "Or through the mobile interface: ssh -i ~/.ssh/id_ed25519 campo@${SERVER_IP}"
echo "====================================="