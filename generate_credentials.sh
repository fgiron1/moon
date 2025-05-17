#!/bin/bash
# Script to set up a password for campo user and save it securely

# Generate a secure password
CAMPO_PASSWORD=$(openssl rand -base64 12)

# Hash the password for Ansible
PASSWORD_HASH=$(python3 -c "import crypt; print(crypt.crypt('$CAMPO_PASSWORD', crypt.mksalt(crypt.METHOD_SHA512)))")

# Create Ansible variable file
mkdir -p inventory/group_vars
cat > inventory/group_vars/campo_credentials.yml << EOF
---
# Campo user credentials
campo_password_hash: "$PASSWORD_HASH"
EOF

# Create an encrypted version with ansible-vault if available
if command -v ansible-vault &> /dev/null; then
    ansible-vault encrypt inventory/group_vars/campo_credentials.yml
    echo "Encrypted credentials file created at inventory/group_vars/campo_credentials.yml"
else
    echo "Warning: ansible-vault not found, credentials saved unencrypted"
fi

# Save the password in a temp file for the user
CREDENTIALS_FILE="campo_credentials.txt"
cat > $CREDENTIALS_FILE << EOF
====================================
OSINT COMMAND CENTER CREDENTIALS
====================================
Server: [Will be displayed after deployment]
User: campo
Password: $CAMPO_PASSWORD
====================================
IMPORTANT: Save this information securely and delete this file afterward.
EOF

echo "Campo user password generated and saved to $CREDENTIALS_FILE"
echo "This file will be used during deployment and should be secured afterward."