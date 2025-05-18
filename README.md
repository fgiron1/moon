# Moon - OSINT Command Center

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

A comprehensive, containerized framework for secure and organized Open Source Intelligence (OSINT) operations.

## 🌟 Features

- **Modular Architecture**: Extensible design with separate modules for different OSINT tasks
- **Containerized Tools**: Pre-configured security tools in isolated containers
- **Secure by Default**: Built-in security measures for safe operations
- **Data Management**: Organized storage and export of collected intelligence
- **Network Privacy**: Advanced routing and VPN integration
- **User-Friendly Interface**: Intuitive terminal-based menu system

## 🚀 Quick Start

### Prerequisites

- Linux-based OS (Ubuntu 20.04+ recommended)
- Docker and Docker Compose
- 4GB+ RAM (8GB recommended)
- 20GB+ free disk space
- Root/sudo access

## ⚙️ Configuration

### Configuration Management

The project uses a two-layer configuration system:
1. **Development/Environment Configuration** (`.env` file)
2. **Deployment Configuration** (Ansible variables)

### 1. Environment Configuration (`.env`)

This is the primary configuration file for local development and deployment:

```bash
# Copy the template
cp .env.template .env

# Edit the configuration
nano .env  # or use your preferred editor
```

### 2. Deployment Configuration

For deployment, the `.env` variables are converted to Ansible variables:

1. **Generate Ansible variables**:
   ```bash
   # Run the conversion script
   ./deploy/scripts/update_ansible_vars.sh
   ```
   
   This will:
   - Read `.env` file
   - Convert variables to Ansible format (lowercase)
   - Save to `deploy/ansible/group_vars/all/env_vars.yml`

2. **Variable Mapping**:
   | .env Variable | Ansible Variable | Example |
   |----------------|------------------|---------|
   | `DATA_DIR`     | `data_dir`       | `/opt/osint/data` |
   | `LOG_LEVEL`    | `log_level`      | `INFO`  |


3. **Using Variables in Ansible**:
   ```yaml
   # Example in osint_servers.yml
   data_directory: "{{ data_dir | default('/opt/osint/data') }}"
   ```

### Best Practices

1. **Never commit sensitive data** to version control
2. **Always run** `update_ansible_vars.sh` after changing `.env`
3. Use `default()` filter in Ansible for fallback values
4. Document new variables in `.env.template`

### Server Configuration
- `SERVER_IP`: Your server's public IP address
- `SERVER_REGION`: Server region (e.g., 'EU', 'US')
- `SERVER_USER`: Default SSH user (default: 'root')
- `SSH_KEY_PATH`: Path to SSH private key (default: '~/.ssh/id_ed25519')

### Network Configuration
- `PRIMARY_NETWORK_INTERFACE`: Primary network interface (default: 'eth0')

### VPN Configuration (Mullvad)
- `MULLVAD_ACCOUNT_NUMBER`: Your Mullvad account number
- `MULLVAD_ACCOUNT_KEY`: Your Mullvad account key
- `MULLVAD_RELAY_COUNTRY`: VPN relay country code (default: 'se')
- `MULLVAD_RELAY_CITY`: (Optional) Specific city for VPN relay
- `WIREGUARD_ADDRESS`: WireGuard internal network (default: '10.0.0.1/24')

### Database Configuration
- `NEO4J_URI`: Neo4j connection URI (default: 'bolt://localhost:7687')
- `NEO4J_USER`: Neo4j username (default: 'neo4j')
- `NEO4J_PASSWORD`: Neo4j password (default: 'osintpassword')
- `SENTRY_DSN`: Sentry DSN for error tracking

### Directory Configuration
- `DATA_DIR`: Base directory for all data (default: '/opt/osint/data')
- `LOG_DIR`: Directory for log files (default: '/opt/osint/logs')
- `WEB_DATA_DIR`: Web module data (default: '${DATA_DIR}/web')
- `NETWORK_DATA_DIR`: Network module data (default: '${DATA_DIR}/network')
- `IDENTITY_DATA_DIR`: Identity module data (default: '${DATA_DIR}/identity')
- `DOMAIN_DATA_DIR`: Domain module data (default: '${DATA_DIR}/domain')

### Application Settings
- `ENVIRONMENT`: Runtime environment ('development' or 'production')

### User Configuration
- `SSH_PUBLIC_KEY`: SSH public key for authentication
- `CAMPO_PASSWORD`: Password for the 'campo' user account

## 🚀 Deployment

### Prerequisites

#### On your local machine (deployment machine):
- Linux/macOS (for Ansible control node)
- Python 3.8+
- Ansible
- SSH access to target server
- Git

#### On the target server:
- Ubuntu 22.04 LTS (recommended)
- Root access
- SSH server running
- Internet access for package downloads

### Deployment Process

1. **On your local machine, clone the repository**:
   ```bash
   git clone https://github.com/yourusername/moon.git
   cd moon
   ```

2. **Configure deployment settings**:
   ```bash
   # Copy and edit the environment template
   cp .env.template .env
   nano .env  # Update with your settings
   
   # Configure the inventory file
   nano deploy/ansible/inventory/osint_servers.yml
   ```

3. **Install Ansible and dependencies**:
   ```bash
   # On Ubuntu/Debian
   sudo apt update
   sudo apt install -y python3-pip python3-venv
   
   # Create and activate virtual environment
   python3 -m venv venv
   source venv/bin/activate
   
   # Install Ansible and required collections
   pip install ansible
   ansible-galaxy collection install -r deploy/ansible/requirements.yml
   ```

4. **Deploy to target server**:
   ```bash
   # Test Ansible connection
   ansible all -i deploy/ansible/inventory/osint_servers.yml -m ping
   
   # Run the deployment playbook
   ansible-playbook -i deploy/ansible/inventory/osint_servers.yml deploy/ansible/site.yml
   ```

5. **Verify deployment**:
   ```bash
   # Check running containers
   ansible all -i deploy/ansible/inventory/osint_servers.yml -m shell -a "docker ps"
   
   # View logs (example for web container)
   ansible all -i deploy/ansible/inventory/osint_servers.yml -m shell -a "docker logs osint-web"
   ```

### Post-Deployment

1. **Access the web interface** (if applicable):
   ```
   https://your-server-ip:8443
   ```

2. **Access the terminal interface** via SSH:
   ```bash
   ssh osint@your-server-ip
   ```

3. **Common management commands** (run on target server):
   ```bash
   # View container status
   sudo docker ps -a
   
   # View logs for a container
   sudo docker logs osint-web
   
   # Access container shell
   sudo docker exec -it osint-web /bin/bash
   
   # Restart services
   sudo docker restart osint-web osint-network
   ```

### Development Mode (Single Machine)

For development or testing on a single machine:

1. **Clone and set up the repository** as shown above
2. **Build and start containers**:
   ```bash
   # Make the manager script executable
   chmod +x core/containers/manager.sh
   
   # Build and start all containers
   sudo ./core/containers/manager.sh build all
   sudo ./core/containers/manager.sh start all
   ```

3. **Access the terminal interface**:
   ```bash
   sudo ./ui/terminal/main.sh
   ```

### Production Deployment

For production deployments, use the automated deployment script:

1. **Clone the repository** on your management machine:
   ```bash
   git clone https://github.com/yourusername/moon.git
   cd moon
   ```

2. **Install Ansible** (if not already installed):
   ```bash
   sudo apt update
   sudo apt install -y ansible
   ```

3. **Configure the inventory**:
   Edit `deploy/ansible/inventory/osint_servers.yml` to specify your target servers.

4. **Set up environment variables**:
   Copy the example environment file and update it with your configuration:
   ```bash
   cp .env.example .env
   nano .env  # Update with your settings
   ```

5. **Run the deployment script**:
   ```bash
   sudo ./deploy/scripts/deploy.sh
   ```
   
   This will:
   - Generate SSH keys if needed
   - Run Ansible playbooks to configure the system
   - Set up containers and services
   - Configure networking and security

6. **Verify the deployment**:
   ```bash
   # Check container status
   sudo ./core/containers/manager.sh status
   
   # Check network configuration
   sudo ./core/network/control.sh status
   ```

## 🛠️ Core Components

### Network Management (`core/network/control.sh`)
- Interface management and monitoring
- Secure DNS configuration with privacy-focused resolvers
- Advanced routing for operational security
- Leak prevention mechanisms
- USB tethering support

### Security Components (`core/security/`)
- **credentials.sh**: Secure credential management with AES-256-CBC encryption
- **wipe.sh**: Secure data deletion with multiple wiping modes

## 📚 Documentation

### Terminal Interface

The terminal interface provides access to various OSINT modules:

1. **Domain Intelligence**
   - Subdomain enumeration
   - DNS analysis
   - WHOIS lookups

2. **Network Scanning**
   - Port scanning
   - Service detection
   - Vulnerability assessment

3. **Identity Research**
   - Username searches
   - Email investigations
   - Social media discovery

4. **Web Analysis**
   - Technology detection
   - Content discovery
   - Security headers analysis

5. **Security & Privacy**
   - VPN management
   - Tor routing
   - DNS privacy

6. **System Controls**
   - Tool updates
   - System status
   - Data management

## 🔒 Security Best Practices

1. Always use a VPN when conducting OSINT operations
2. Regularly update all tools and dependencies
3. Review collected data before sharing or storing
4. Use secure wipe for sensitive information
5. Maintain operational security by limiting data exposure

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📧 Contact

For support or questions, please open an issue on our GitHub repository.

---

💡 **Tip**: Always ensure you have proper authorization before performing any security testing or scanning activities.
