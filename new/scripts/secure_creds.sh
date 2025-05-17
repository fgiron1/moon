#!/bin/bash

# Secure credential management script
# This script creates encrypted credential files and removes plaintext versions

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# Create secure directory for credentials
CREDS_DIR="/opt/osint/secure_creds"
mkdir -p $CREDS_DIR
chmod 700 $CREDS_DIR

# Function to securely store credentials
store_credential() {
    local name=$1
    local value=$2
    local file="$CREDS_DIR/$name"
    
    # Encrypt the credential
    echo -n "$value" | openssl enc -aes-256-cbc -salt -out "$file.enc" -pass file:/root/.cred_key
    
    # Set secure permissions
    chmod 600 "$file.enc"
    
    echo -e "${GREEN}Credential $name securely stored${NC}"
}

# Generate a random key for encryption if it doesn't exist
if [ ! -f /root/.cred_key ]; then
    openssl rand -base64 32 > /root/.cred_key
    chmod 600 /root/.cred_key
fi

# Process environment variables from .env file
if [ -f .env ]; then
    echo -e "${YELLOW}Processing credentials from .env file...${NC}"
    while IFS='=' read -r key value
    do
        # Skip commented or empty lines
        [[ $key == \#* ]] || [ -z "$key" ] && continue
        
        # Store each credential
        store_credential "$key" "$value"
        echo -e "${YELLOW}Securely stored $key${NC}"
    done < .env
    
    # Create a backup of the original .env file
    cp .env .env.bak
    
    # Securely wipe the original .env file
    shred -n 10 -z -u .env
    echo -e "${GREEN}Original .env file securely deleted${NC}"
else
    echo -e "${RED}No .env file found${NC}"
fi

# Process campo_credentials.txt if it exists
if [ -f campo_credentials.txt ]; then
    echo -e "${YELLOW}Processing campo credentials...${NC}"
    
    # Extract password
    CAMPO_PASS=$(grep -oP "Password: \K.*" campo_credentials.txt)
    
    if [ -n "$CAMPO_PASS" ]; then
        store_credential "CAMPO_PASSWORD" "$CAMPO_PASS"
        echo -e "${GREEN}Campo password securely stored${NC}"
        
        # Create a backup
        cp campo_credentials.txt campo_credentials.txt.bak
        
        # Securely wipe the original file
        shred -n 10 -z -u campo_credentials.txt
        echo -e "${GREEN}Original campo_credentials.txt securely deleted${NC}"
    else
        echo -e "${RED}Could not extract campo password${NC}"
    fi
else
    echo -e "${YELLOW}No campo_credentials.txt file found${NC}"
fi

echo -e "${GREEN}Credentials have been securely stored in $CREDS_DIR${NC}"
echo -e "${YELLOW}Backups of the original files were created for reference${NC}"
echo -e "${YELLOW}You can safely delete the backup files when ready${NC}"