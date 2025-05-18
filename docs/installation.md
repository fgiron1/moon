# OSINT Command Center Installation Guide

## Prerequisites

### System Requirements
- Ubuntu 22.04 LTS or compatible
- 4GB RAM minimum
- 2 CPU cores
- 50GB disk space
- Internet connection for initial setup

### Required Software
- Docker/Nerdctl
- Ansible 2.9+
- Python 3.8+
- Git

## Initial Setup

1. Clone the repository:
```bash
git clone https://github.com/your-username/moon.git
cd moon
```

2. Create environment file:
```bash
cp .env.template .env
```

3. Edit `.env` with your configuration:
```bash
# Required Variables
SSH_PORT=2222
VPN_PROVIDER=mullvad
ALLOWED_USERS="moon_user"

# Database
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=your_secure_password

# Directories
DATA_DIR=/opt/osint/data
LOG_DIR=/opt/osint/logs
ENVIRONMENT=production
```

## System Installation

1. Install system dependencies:
```bash
./deploy/scripts/install_dependencies.sh
```

2. Run Ansible deployment:
```bash
./deploy/scripts/deploy.sh
```

## Container Setup

1. Build containers:
```bash
cd core/containers
./manager.sh build_all
```

2. Start containers:
```bash
./manager.sh start_all
```

## Post-Installation Verification

1. Verify system services:
```bash
systemctl status ssh
systemctl status docker
systemctl status fail2ban
```

2. Verify container status:
```bash
cd core/containers
./manager.sh list
```

## Troubleshooting

### Common Issues

1. **Container Build Failures**
   - Check logs in `/opt/osint/logs`
   - Verify Docker/Nerdctl installation
   - Check disk space

2. **Network Connectivity**
   - Verify UFW rules
   - Check VPN connection
   - Verify Neo4j ports

3. **Security Alerts**
   - Check Fail2ban logs
   - Review security audit reports
   - Verify SSH access

## Backup & Recovery

1. Create backup:
```bash
cd core/containers
./manager.sh backup
```

2. Restore backup:
```bash
# Coming soon in future release
```

## Security Notes

- All containers are restricted to 2GB RAM and 2 CPU cores
- Network access is restricted to essential ports
- Regular security audits are performed
- Fail2ban is configured for SSH protection
- UFW denies all incoming traffic by default
