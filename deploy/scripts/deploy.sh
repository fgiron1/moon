#!/bin/bash

# Colors
GREEN=\'\033[0;32m\'
BLUE=\'\033[0;34m\'
RED=\'\033[0;31m\'
YELLOW=\'\033[1;33m\'
NC=\'\033[0m\' # No Color

# Directory structure
PROJECT_ROOT=$(pwd)
CREDS_DIR="$PROJECT_ROOT/secure_creds"
ANSIBLE_DIR="$PROJECT_ROOT/deploy/ansible"

# Function to check required tools
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    local missing=0
    
    for cmd in ansible-playbook ssh-keygen; do
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

# Function to load environment variables
load_environment() {
    echo -e "${BLUE}Loading environment variables...${NC}"
    
    if [ ! -f ".env" ]; then
        echo -e "${RED}Error: .env file not found${NC}"
        echo -e "${YELLOW}Creating .env from template...${NC}"
        cp .env.template .env
    fi
    
    if [ ! -f ".env" ]; then
        echo -e "${RED}Error: Failed to create .env file${NC}"
        exit 1
    fi
    
    # Load environment variables
    export $(grep -v '^#' .env | xargs)
    
    echo -e "${GREEN}Environment variables loaded successfully${NC}"
}

# Function to generate SSH key if needed
generate_ssh_key() {
    echo -e "${BLUE}Checking SSH keys...${NC}"
    
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo -e "${YELLOW}Generating new SSH key...${NC}"
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "moon_ssh_key"
        echo -e "${GREEN}SSH key generated successfully${NC}"
    else
        echo -e "${GREEN}SSH key already exists${NC}"
    fi
}

# Function to run Ansible playbook
run_ansible() {
    echo -e "${BLUE}Running Ansible playbook...${NC}"
    
    # Run the main playbook
    ansible-playbook "$ANSIBLE_DIR/playbooks/main.yml" \
        -i "$ANSIBLE_DIR/inventory/osint_servers.yml" \
        --private-key="$SSH_KEY_PATH" \
        -e "@.env"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Ansible playbook completed successfully${NC}"
    else
        echo -e "${RED}Error: Ansible playbook failed${NC}"
        exit 1
    fi
}

# Function to configure VPN
configure_vpn() {
    echo -e "${BLUE}Configuring VPN...${NC}"
    
    # Run VPN specific tasks
    ansible-playbook "$ANSIBLE_DIR/playbooks/security_enhancements.yml" \
        -i "$ANSIBLE_DIR/inventory/osint_servers.yml" \
        --private-key="$SSH_KEY_PATH" \
        -e "@.env"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}VPN configuration completed successfully${NC}"
    else
        echo -e "${RED}Error: VPN configuration failed${NC}"
        exit 1
    fi
}

# Main function
main() {
    echo -e "${BLUE}Starting Moon deployment...${NC}"
    
    # Check prerequisites
    check_prerequisites
    
    # Load environment
    load_environment
    
    # Generate SSH key
    generate_ssh_key
    
    # Run main deployment
    run_ansible
    
    # Configure VPN
    configure_vpn
    
    echo -e "${GREEN}Deployment completed successfully!${NC}"
}

# Run the main function
main

exit 0
