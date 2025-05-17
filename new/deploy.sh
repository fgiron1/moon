#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directory structure
PROJECT_ROOT=$(pwd)
CREDS_DIR="/opt/osint/secure_creds"
CONTAINERS_DIR="$PROJECT_ROOT/containers"

# Function to check required tools
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    local missing=0
    
    for cmd in terraform ansible-playbook ssh-keygen; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}Error: $cmd is not installed${NC}"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo -e "${RED}Please install missing prerequisites and try again${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All prerequisites are installed${NC}"
}

# Function to load credentials securely
load_credentials() {
    echo -e "${BLUE}Loading credentials...${NC}"
    
    # Check if .env exists, if so prompt to secure it
    if [ -f .env ]; then
        echo -e "${YELLOW}Warning: Unsecured .env file detected${NC}"
        read -p "Would you like to secure these credentials? [Y/n] " secure_creds
        
        if [[ "$secure_creds" != "n" && "$secure_creds" != "N" ]]; then
            ./scripts/secure_creds.sh
        fi
    fi
    
    # Check if secure credentials exist
    if [ ! -d "$CREDS_DIR" ]; then
        echo -e "${YELLOW}No secure credentials found.${NC}"
        
        # Prompt for Contabo API credentials
        read -p "Enter your Contabo API Client ID: " CONTABO_CLIENT_ID
        read -p "Enter your Contabo API Client Secret: " CONTABO_CLIENT_SECRET
        read -p "Enter your Contabo API Username: " CONTABO_USERNAME
        read -sp "Enter your Contabo API Password: " CONTABO_PASSWORD
        echo
        
        # Create secure credentials directory
        sudo mkdir -p "$CREDS_DIR"
        sudo chmod 700 "$CREDS_DIR"
        
        # Generate a random key for encryption if it doesn't exist
        if [ ! -f /root/.cred_key ]; then
            sudo openssl rand -base64 32 | sudo tee /root/.cred_key > /dev/null
            sudo chmod 600 /root/.cred_key
        fi
        
        # Store credentials securely
        echo -n "$CONTABO_CLIENT_ID" | sudo openssl enc -aes-256-cbc -salt -out "$CREDS_DIR/CONTABO_CLIENT_ID.enc" -pass file:/root/.cred_key
        echo -n "$CONTABO_CLIENT_SECRET" | sudo openssl enc -aes-256-cbc -salt -out "$CREDS_DIR/CONTABO_CLIENT_SECRET.enc" -pass file:/root/.cred_key
        echo -n "$CONTABO_USERNAME" | sudo openssl enc -aes-256-cbc -salt -out "$CREDS_DIR/CONTABO_USERNAME.enc" -pass file:/root/.cred_key
        echo -n "$CONTABO_PASSWORD" | sudo openssl enc -aes-256-cbc -salt -out "$CREDS_DIR/CONTABO_PASSWORD.enc" -pass file:/root/.cred_key
        
        sudo chmod 600 "$CREDS_DIR"/*.enc
    else
        # Load credentials from secure storage
        CONTABO_CLIENT_ID=$(sudo openssl enc -d -aes-256-cbc -in "$CREDS_DIR/CONTABO_CLIENT_ID.enc" -pass file:/root/.cred_key 2>/dev/null)
        CONTABO_CLIENT_SECRET=$(sudo openssl enc -d -aes-256-cbc -in "$CREDS_DIR/CONTABO_CLIENT_SECRET.enc" -pass file:/root/.cred_key 2>/dev/null)
        CONTABO_USERNAME=$(sudo openssl enc -d -aes-256-cbc -in "$CREDS_DIR/CONTABO_USERNAME.enc" -pass file:/root/.cred_key 2>/dev/null)
        CONTABO_PASSWORD=$(sudo openssl enc -d -aes-256-cbc -in "$CREDS_DIR/CONTABO_PASSWORD.enc" -pass file:/root/.cred_key 2>/dev/null)
    fi
    
    # Check if we have required credentials
    if [ -z "$CONTABO_CLIENT_ID" ] || [ -z "$CONTABO_CLIENT_SECRET" ] || [ -z "$CONTABO_USERNAME" ] || [ -z "$CONTABO_PASSWORD" ]; then
        echo -e "${RED}Error: Missing required Contabo API credentials${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Credentials loaded successfully${NC}"
}

# Function to generate SSH key if needed
generate_ssh_key() {
    echo -e "${BLUE}Checking SSH keys...${NC}"
    
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo -e "${YELLOW}SSH key not found, generating new ED25519 key at $SSH_KEY_PATH${NC}"
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
        echo -e "${GREEN}SSH key generated${NC}"
    else
        echo -e "${GREEN}SSH key found at $SSH_KEY_PATH${NC}"
    fi
}

# Function to provision infrastructure
provision_infrastructure() {
    echo -e "${BLUE}Provisioning infrastructure...${NC}"
    
    # Export credentials for Terraform
    export TF_VAR_contabo_client_id="$CONTABO_CLIENT_ID"
    export TF_VAR_contabo_client_secret="$CONTABO_CLIENT_SECRET"
    export TF_VAR_contabo_username="$CONTABO_USERNAME"
    export TF_VAR_contabo_password="$CONTABO_PASSWORD"
    
    # Initialize and apply Terraform
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init
    
    echo -e "${YELLOW}Applying Terraform configuration...${NC}"
    terraform apply -auto-approve
    
    # Get server IP
    SERVER_IP=$(terraform output -raw server_ip)
    
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}Error: Failed to get server IP from Terraform${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Server provisioned with IP: $SERVER_IP${NC}"
    
    # Create dynamic Ansible inventory
    echo -e "${YELLOW}Creating Ansible inventory...${NC}"
    sed "s/{{ server_ip }}/$SERVER_IP/g" ansible/inventory/hosts.yml.template > ansible/inventory/hosts.yml
}

# Function to wait for SSH
wait_for_ssh() {
    local server_ip=$1
    local ssh_key="$HOME/.ssh/id_ed25519"
    local max_attempts=20
    local attempt=1
    
    echo -e "${YELLOW}Waiting for SSH to become available on $server_ip...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -i "$ssh_key" root@$server_ip echo "SSH connection successful" &>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}SSH connection established${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Attempt $attempt/$max_attempts - Retrying in 10 seconds...${NC}"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}Failed to connect to server via SSH after $max_attempts attempts${NC}"
    exit 1
}

# Function to configure server with Ansible
configure_server() {
    local server_ip=$1
    
    echo -e "${BLUE}Configuring server with Ansible...${NC}"
    
    # Run base setup
    echo -e "${YELLOW}Running base server setup...${NC}"
    ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/base_setup.yml
    
    # Install containerd
    echo -e "${YELLOW}Installing containerd...${NC}"
    ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/containerd_setup.yml
    
    # Run security hardening
    echo -e "${YELLOW}Running security hardening...${NC}"
    ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/security.yml
    
    echo -e "${GREEN}Server configuration completed${NC}"
}

# Function to build and deploy containers
deploy_containers() {
    local server_ip=$1
    
    echo -e "${BLUE}Building and deploying containers...${NC}"
    
    # Transfer container definitions
    echo -e "${YELLOW}Transferring container definitions...${NC}"
    scp -r -i "$HOME/.ssh/id_ed25519" "$CONTAINERS_DIR" root@$server_ip:/opt/osint/
    
    # Build base container
    echo -e "${YELLOW}Building base container...${NC}"
    ssh -i "$HOME/.ssh/id_ed25519" root@$server_ip "cd /opt/osint/containers/base && nerdctl build -t osint-base:latest ."
    
    # Build tool containers
    echo -e "${YELLOW}Building tool containers...${NC}"
    ssh -i "$HOME/.ssh/id_ed25519" root@$server_ip "cd /opt/osint/containers/domain_intel && nerdctl build -t osint-domain-intel:latest ."
    ssh -i "$HOME/.ssh/id_ed25519" root@$server_ip "cd /opt/osint/containers/network_scan && nerdctl build -t osint-network-scan:latest ."
    
    echo -e "${GREEN}Containers built and deployed successfully${NC}"
}

# Function to configure the network for containers
configure_network() {
    local server_ip=$1
    
    echo -e "${BLUE}Configuring container networking...${NC}"
    
    # Transfer network script
    scp -i "$HOME/.ssh/id_ed25519" ansible/roles/networking/templates/container_network.sh.j2 root@$server_ip:/usr/local/bin/container-network
    ssh -i "$HOME/.ssh/id_ed25519" root@$server_ip "chmod +x /usr/local/bin/container-network"
    
    # Set up container network
    ssh -i "$HOME/.ssh/id_ed25519" root@$server_ip "/usr/local/bin/container-network setup eth0"
    
    echo -e "${GREEN}Container networking configured successfully${NC}"
}

# Main function
main() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}  OSINT Command Center Deployment${NC}"
    echo -e "${BLUE}=================================${NC}"
    
    check_prerequisites
    load_credentials
    generate_ssh_key
    provision_infrastructure
    
    # Get the server IP
    SERVER_IP=$(terraform output -raw server_ip)
    
    wait_for_ssh "$SERVER_IP"
    configure_server "$SERVER_IP"
    deploy_containers "$SERVER_IP"
    configure_network "$SERVER_IP"
    
    echo -e "${BLUE}=================================${NC}"
    echo -e "${GREEN}  Deployment Completed Successfully${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo -e "Server IP: ${YELLOW}$SERVER_IP${NC}"
    echo -e "Connect with: ${YELLOW}ssh -i $HOME/.ssh/id_ed25519 root@$SERVER_IP${NC}"
    echo ""
    echo -e "${RED}IMPORTANT SECURITY NOTICE:${NC}"
    echo -e "1. Password authentication has been disabled for SSH (except for campo user)"
    echo -e "2. All credentials are now stored securely"
    echo -e "3. Additional security hardening has been applied"
    echo -e "${BLUE}=================================${NC}"
}

# Run the main function
main

exit 0