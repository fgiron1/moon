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

## 🚀 Deployment

### Prerequisites

- Linux-based OS (Ubuntu 20.04+ recommended)
- Python 3.8+
- Ansible
- SSH access to target servers (if deploying remotely)

### Local Installation

For a local development or testing environment:

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/moon.git
   cd moon
   ```

2. **Set up the environment**:
   ```bash
   # Create required directories
   sudo mkdir -p /opt/osint/{data,tools,config}
   sudo chown -R $USER:$USER /opt/osint
   
   # Set up data directories
   mkdir -p /opt/osint/data/{targets,exports,reports,logs}
   ```

3. **Build and start the containers**:
   ```bash
   # Build all containers
   sudo ./core/containers/manager.sh build all
   
   # Start all containers
   sudo ./core/containers/manager.sh start all
   ```

4. **Access the terminal interface**:
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
