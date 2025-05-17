# OSINT Command Center Deployment Guide

This guide provides step-by-step instructions for deploying the OSINT Command Center on a Contabo VPS.

## Prerequisites

- Linux or macOS host system
- Terraform (v1.0+)
- Ansible (v2.9+)
- Contabo account with API access
- Internet connection

## Deployment Steps

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/osint-command-center.git
cd osint-command-center
```

### 2. Configure Credentials

Copy the template file and add your Contabo API credentials:

```bash
cp .env.template .env
nano .env  # Add your Contabo API credentials
```

### 3. Generate SSH Key (if needed)

If you don't already have an ED25519 SSH key, one will be automatically generated during deployment. If you want to create your own:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

### 4. Generate Campo User Credentials

The campo user needs a secure password for accessing the mobile interface. Run:

```bash
bash generate_credentials.sh
```

This will create:
- A credential file for Ansible
- A temporary file with campo's password for your reference

### 5. Run the Deployment Script

```bash
bash deploy.sh
```

This script will:
- Initialize Terraform and provision the server
- Wait for SSH to become available
- Run Ansible to configure the server
- Display connection information

### 6. Access Your OSINT Command Center

After deployment completes, you can access your server:

```bash
# As root (full system access)
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP

# As campo user (mobile-friendly interface)
ssh -i ~/.ssh/id_ed25519 campo@SERVER_IP
```

For the campo user, use the password from `campo_credentials.txt`.

### 7. Mobile Access (From Your Phone)

To access from your phone:

1. Install an SSH client (e.g., Termius, JuiceSSH, or Blink Shell)
2. Import your SSH key (transfer it securely to your phone)
3. Configure a connection to `campo@SERVER_IP`
4. Connect and enter your password when prompted

## Troubleshooting

### SSH Connection Issues

If you're having trouble connecting:

```bash
# Verbose connection for troubleshooting
ssh -vvv -i ~/.ssh/id_ed25519 campo@SERVER_IP
```

### Permission Issues

If you encounter permission problems:

```bash
# Check and fix permissions
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP "chmod 755 /usr/local/bin/campo && cat /etc/sudoers.d/campo"
```

### Interface Problems

If the mobile interface doesn't work properly:

```bash
# Restart the campo user session
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP "pkill -u campo && service ssh restart"
```

## Security Considerations

- The server is configured with both key-based and password authentication
- The campo user password should be kept secure
- Consider changing the campo password regularly
- Always use the VPN feature when conducting OSINT operations

## Phone Tethering Setup

To route traffic through your phone:

1. Connect your phone via USB to the server
2. Enable USB tethering on your phone
3. In the mobile interface, go to Security & Privacy > Network controls > Set up phone tethering
4. Follow the on-screen instructions

## Additional Information

For more detailed information about the OSINT Command Center, refer to the README.md file in the repository root.