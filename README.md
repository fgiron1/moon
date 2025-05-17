# OSINT Command Center

A comprehensive, self-contained OSINT (Open Source Intelligence) server with advanced features for security researchers, ethical hackers, and privacy-conscious investigators.

![OSINT Command Center Logo](https://raw.githubusercontent.com/yourusername/osint-command-center/main/docs/images/logo.png)

## Overview

OSINT Command Center provides a fully automated deployment of a robust OSINT server with a mobile-friendly interface, extensive toolset, and advanced privacy features. The system is designed with several key capabilities:

- **Mobile-First Operation**: SSH into your server from your smartphone and access a touch-friendly interface designed for field operations
- **Network Interface Flexibility**: Route OSINT tool traffic through any network interface, including a tethered mobile phone
- **Data Collection & Correlation**: Gather and correlate intelligence across multiple sources with our lightweight Rust-based engine
- **Privacy & Security**: Strong VPN integration, Tor routing, and comprehensive security features to protect your identity
- **Comprehensive Toolset**: Integrates leading OSINT tools including bbot, Sherlock, SpiderFoot, and more

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Installation](#installation)
- [Usage Guide](#usage-guide)
  - [Mobile Interface](#mobile-interface)
  - [Network Control](#network-control)
  - [OSINT Tools](#osint-tools)
  - [Data Correlation](#data-correlation)
  - [VPN and Tor](#vpn-and-tor)
- [Security Guidelines](#security-guidelines)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/osint-command-center.git
cd osint-command-center

# Create .env file with your cloud provider credentials
cp .env.template .env
nano .env  # Edit with your Contabo API credentials

# Deploy the server
bash deploy.sh

# Once deployed, connect to the server:
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP

# For mobile-friendly interface:
ssh -i ~/.ssh/id_ed25519 campo@SERVER_IP
```

## Features

### Core Features

- **Infrastructure as Code**: Fully automated deployment using Terraform and Ansible
- **Mobile-Friendly Interface**: Menu-driven system optimized for smartphone SSH clients
- **Network Interface Control**: Direct OSINT traffic through any interface, including USB tethered phones
- **Data Correlation**: Lightweight Rust-based engine to process and correlate OSINT data
- **Privacy Protection**: VPN integration, Tor routing, and comprehensive security measures

### OSINT Tools Included

- **Person/Identity Research**
  - bbot (BlackLanternSecurity OSINT framework)
  - Sherlock (Username search across platforms)
  - Maigret (Advanced social media discovery)
  - Holehe (Email account finder)
  - PhoneInfoga (Phone number analysis)

- **Network/Domain Intelligence**
  - SpiderFoot (Automated OSINT framework)
  - theHarvester (Email and subdomain harvester)
  - bbot modules (Domain/subdomain analysis)
  - Recon-ng (Web reconnaissance framework)

- **Wireless/RF Capabilities**
  - Bluetooth scanning and analysis
  - WiFi network discovery
  - RFID tools (with appropriate hardware)

### Security & Privacy Features

- **VPN Integration**: WireGuard VPN with Mullvad
- **Tor Routing**: Transparent routing through Tor network
- **Data Security**: Secure wiping and anti-forensics tools
- **Access Security**: Fail2ban, SSH hardening, firewall controls

## Installation

### Prerequisites

- Linux or macOS with:
  - Terraform (v1.0+)
  - Ansible (v2.9+)
  - SSH key pair (preferably ED25519)
  - Contabo API credentials (or modify for your preferred cloud provider)

### Deployment Steps

1. **Clone the repository**

```bash
git clone https://github.com/yourusername/osint-command-center.git
cd osint-command-center
```

2. **Configure your environment**

```bash
cp .env.template .env
nano .env  # Add your cloud provider credentials
```

3. **Customize configuration (optional)**

Edit files in the `inventory/` directory to customize your deployment:
- `inventory/group_vars/all.yml`: Common settings
- `inventory/group_vars/osint_servers.yml`: Tool configurations
- `inventory/host_vars/osint_server.yml`: Server-specific settings

4. **Deploy the server**

```bash
bash deploy.sh
```

5. **Access your OSINT Command Center**

```bash
# As root (full system access)
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP

# As campo user (mobile-friendly interface)
ssh -i ~/.ssh/id_ed25519 campo@SERVER_IP
```

## Usage Guide

### Mobile Interface

The Campo mobile interface is automatically launched when you connect as the `campo` user. It provides a touch-friendly menu system optimized for smartphone SSH clients.

**Main menu sections:**

1. **Person Investigation**: Username, email, and phone number lookups
2. **Domain/Network Analysis**: Domain reconnaissance and network scanning
3. **RF/Wireless Tools**: Bluetooth, WiFi, and RFID scanning
4. **Security & Privacy**: VPN controls, privacy checkup, network interface management
5. **System Controls**: Update tools, system status, data management

**Example operations:**

```bash
# Connect to the mobile interface
ssh -i ~/.ssh/id_ed25519 campo@SERVER_IP

# Then navigate the menu to:
# 1. Person Investigation > 2. Username search > Enter username: target_username
# The result will show platforms where the username is found
```

### Network Control

The Network Control feature allows you to route OSINT tool traffic through specific interfaces, including a tethered mobile phone.

**Command line usage:**

```bash
# List available network interfaces
sudo osint-network list

# Show current routing status
sudo osint-network status

# Set up USB tethering with Android phone
sudo osint-network phone

# Route traffic for campo user through wlan0 interface
sudo osint-network use wlan0 campo

# Route traffic for campo user through USB tethered phone (usb0)
sudo osint-network use usb0 campo

# Reset routing to default
sudo osint-network reset
```

**Mobile interface navigation:**
Security & Privacy > Network Controls > [Select option]

### OSINT Tools

Access the complete suite of OSINT tools through either the mobile interface or directly via the command line.

**Username Search:**

```bash
# Using sherlock
cd /opt/osint/tools/sherlock && python3 sherlock.py username

# Using maigret
cd /opt/osint/tools/maigret && python3 -m maigret username

# Using bbot
cd /opt/osint/tools/bbot && python -m bbot -t username -m social -f terminal
```

**Domain Analysis:**

```bash
# Subdomain enumeration with bbot
cd /opt/osint/tools/bbot && python -m bbot -t example.com -m subdomain-enum -f terminal

# Email harvesting with theHarvester
cd /opt/osint/tools/theHarvester && python3 theHarvester.py -d example.com -b all

# Full scan with SpiderFoot
cd /opt/osint/tools/spiderfoot && python3 sf.py -l 0.0.0.0:8080
# Then visit http://YOUR_SERVER_IP:8080 in your browser
```

**Email Investigation:**

```bash
# Check for accounts using an email with holehe
cd /opt/osint/tools/holehe && python3 -m holehe email@example.com
```

**Phone Number Analysis:**

```bash
# Analyze phone number with PhoneInfoga
cd /opt/osint/tools/phoneinfoga && python3 phoneinfoga.py -n +1234567890
```

### Data Correlation

The Rust-based data correlation engine allows you to extract, correlate, and visualize relationships between entities found by different OSINT tools.

```bash
# Run full analysis on a target
osint-correlator analyze johndoe --data-dir /opt/osint/data

# Generate visualizations from existing analysis
osint-correlator visualize /opt/osint/analysis/output/johndoe_20250517_123456 --format svg

# Generate report from existing analysis
osint-correlator report /opt/osint/analysis/output/johndoe_20250517_123456 --format html
```

### VPN and Tor

Protect your identity with VPN and Tor routing controls:

**VPN Controls:**

```bash
# Enable VPN
vpn on

# Check VPN status
vpn status

# Disable VPN
vpn off
```

**Tor Controls:**

```bash
# Enable transparent Tor routing
tor-control on

# Check Tor status
tor-control status

# Disable Tor routing
tor-control off
```

**Mobile interface navigation:**
Security & Privacy > VPN Controls or Anti-tracking Tools

## Security Guidelines

For optimal security during OSINT operations:

1. **Always use VPN or Tor** when conducting sensitive research
2. **Route through your phone** when additional anonymity is required
3. **Compartmentalize your research** by creating separate data directories for different targets
4. **Regularly wipe sensitive data** using the secure wipe tool
5. **Update tools regularly** to ensure you have the latest security patches
6. **Check your actual IP** before starting sensitive work with `vpn status` or `tor-control status`
7. **Review the security guides** in `/opt/osint/safety/` directory

### Personal Security Guides

The system includes comprehensive security guides at:
- `/opt/osint/safety/personal_security_tips.md`
- `/opt/osint/safety/secure_comms_guide.md`

Review these documents for best practices on:
- Physical security
- Digital security
- Operational security
- Social engineering defense
- Emergency procedures

## Customization

### Adding New Tools

1. Add the tool to `inventory/group_vars/osint_servers.yml`:

```yaml
osint_tools:
  - name: "new-tool"
    repo: "https://github.com/author/new-tool.git"
    dest: "{{ osint_tools_dir }}/new-tool"
    pip_requirements: true
```

2. Run Ansible to update the server:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/osint_tools.yml
```

### Changing VPN Provider

1. Create a new template in `roles/vpn/templates/` for your VPN provider
2. Update `roles/vpn/tasks/main.yml` with appropriate configuration steps
3. Update `inventory/host_vars/osint_server.yml` with your VPN settings
4. Run Ansible to apply changes:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/vpn_setup.yml
```

### Modifying the Mobile Interface

Edit the template at `roles/mobile_interface/templates/campo_menu.sh.j2` and run:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/mobile_interface.yml
```

## Troubleshooting

### Network Interface Issues

**Problem**: Unable to route traffic through phone

**Solution**:
```bash
# Ensure phone is properly connected with USB tethering enabled
# Check for USB network interfaces
ip link show | grep -E "usb|enp0s"

# Verify the interface has an IP address
ip addr show usb0

# Try manual setup
sudo dhclient usb0
sudo osint-network use usb0 campo
```

### VPN Connection Problems

**Problem**: VPN won't connect

**Solution**:
```bash
# Check WireGuard module
lsmod | grep wireguard

# Verify configuration
cat /etc/wireguard/mullvad.conf

# Check logs
journalctl -u wg-quick@mullvad

# Try restarting with verbose logging
wg-quick down mullvad
wg-quick up mullvad
```

### Tool Functionality Issues

**Problem**: OSINT tool fails to run

**Solution**:
```bash
# Update the tool
cd /opt/osint/tools/problematic-tool
git pull
pip install -r requirements.txt

# Check for Python environment issues
python3 -m pip freeze

# Look for error logs
cat /opt/osint/logs/tool_errors.log
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- The bbot team at BlackLanternsecurity
- All the developers of the included OSINT tools
- The OSINT community for continued research and development

---

**Disclaimer**: This tool is provided for legitimate security research and ethical purposes only. Users are responsible for complying with applicable laws and regulations.

---

© 2025 OSINT Command Center Project