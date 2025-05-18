# OSINT Command Center Deployment Guide

This guide provides step-by-step instructions for deploying the OSINT Command Center on a Contabo VPS.

## Prerequisites

- Linux or macOS host system
- Terraform (v1.0+)
- Ansible (v2.9+)
- Contabo account with API access
- SSH key pair (ED25519 preferred)
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

Required environment variables:
- `CONTABO_CLIENT_ID`: Your Contabo API client ID
- `CONTABO_CLIENT_SECRET`: Your Contabo API client secret
- `CONTABO_USERNAME`: Your Contabo API username
- `CONTABO_PASSWORD`: Your Contabo API password
- `SERVER_REGION`: Target region for the server (default: EU)
- `PRIMARY_NETWORK_INTERFACE`: Primary network interface (default: eth0)

### 3. Generate SSH Key (if needed)

If you don't already have an ED25519 SSH key, create one:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

### 4. Run the Deployment Script

```bash
bash deploy/scripts/deploy.sh
```

This script will:
- Initialize Terraform and provision the server
- Wait for SSH to become available
- Run Ansible to configure the server
- Display connection information

### 5. Access Your OSINT Command Center

After deployment completes, you can access your server:

```bash
# As root (full system access)
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP

# As campo user (mobile-friendly interface)
ssh -i ~/.ssh/id_ed25519 campo@SERVER_IP
```

For the campo user, use the password provided at the end of the deployment process.

### 6. Mobile Access (From Your Phone)

To access from your phone:

1. Install an SSH client (e.g., Termius, JuiceSSH, or Blink Shell)
2. Import your SSH key (transfer it securely to your phone)
3. Configure a connection to `campo@SERVER_IP`
4. Connect and enter your password when prompted

## Customizing the Deployment

### Changing Server Specifications

Edit the `deploy/terraform/main.tf` file to modify the server specifications:

```terraform
resource "contabo_instance" "osint_server" {
  display_name = "osint-command-center"
  product_id   = "V1"  # Cloud VPS specification - change as needed
  region       = "EU"  # Region - change as needed
  
  image_id     = "ubuntu-22.04"
  
  # Configure SSH key
  ssh_keys     = [contabo_ssh_key.main_key.id]
}
```

### Customizing Tool Installation

Edit the Ansible configuration in `deploy/ansible/inventory/group_vars/osint_servers.yml` to customize which tools are installed:

```yaml
osint_tools:
  - name: "amass"
    enabled: true
  - name: "subfinder"
    enabled: true
  # Add or remove tools as needed
```

### Configuring Security Settings

Security settings can be customized in `deploy/ansible/inventory/group_vars/all.yml`:

```yaml
security:
  ssh:
    permit_root_login: "prohibit-password"
    password_authentication: false
    max_auth_tries: 3
  
  firewall:
    default_policy: DROP
    allowed_ports:
      - 22/tcp  # SSH
```

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

### Container Problems

If containers are not running properly:

```bash
# Check container status
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP "sudo /opt/osint/core/containers/manager.sh status"

# Restart containers
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP "sudo /opt/osint/core/containers/manager.sh restart"
```

## Security Considerations

- The server is configured with both key-based and password authentication
- The campo user password should be kept secure
- Consider changing the campo password regularly
- Always use the VPN feature when conducting OSINT operations

## Additional Information

For more detailed information about the OSINT Command Center, refer to the user guides in the [docs/user-guides](../user-guides/) directory.

---

© 2025 OSINT Command Center Project