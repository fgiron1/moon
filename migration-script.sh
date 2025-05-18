#!/bin/bash

# OSINT Command Center Migration Script
# This script migrates the project to the new structure

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define paths
PROJECT_ROOT=$(pwd)
NEW_DIR="$PROJECT_ROOT/new"

# Function to create directories
create_directory_structure() {
  echo -e "${BLUE}Creating directory structure...${NC}"
  
  # Create main directories
  mkdir -p "$NEW_DIR/deploy/terraform"
  mkdir -p "$NEW_DIR/deploy/ansible/inventory"
  mkdir -p "$NEW_DIR/deploy/ansible/playbooks"
  mkdir -p "$NEW_DIR/deploy/ansible/roles"
  mkdir -p "$NEW_DIR/deploy/scripts"
  
  mkdir -p "$NEW_DIR/core/containers/base"
  mkdir -p "$NEW_DIR/core/containers/network"
  mkdir -p "$NEW_DIR/core/containers/identity"
  mkdir -p "$NEW_DIR/core/containers/web"
  mkdir -p "$NEW_DIR/core/containers/data"
  mkdir -p "$NEW_DIR/core/network"
  mkdir -p "$NEW_DIR/core/security"
  
  mkdir -p "$NEW_DIR/tools/domain"
  mkdir -p "$NEW_DIR/tools/network"
  mkdir -p "$NEW_DIR/tools/identity"
  mkdir -p "$NEW_DIR/tools/web"
  mkdir -p "$NEW_DIR/tools/data-correlation"
  
  mkdir -p "$NEW_DIR/ui/terminal"
  mkdir -p "$NEW_DIR/ui/web"
  
  mkdir -p "$NEW_DIR/docs/user-guides"
  mkdir -p "$NEW_DIR/docs/security"
  mkdir -p "$NEW_DIR/docs/deployment"
  
  mkdir -p "$NEW_DIR/scripts"
  
  echo -e "${GREEN}Directory structure created${NC}"
}

# Function to migrate Ansible configuration
migrate_ansible() {
  echo -e "${BLUE}Migrating Ansible configuration...${NC}"
  
  # Copy ansible.cfg
  cp "$PROJECT_ROOT/ansible/ansible.cfg" "$NEW_DIR/deploy/ansible/"
  
  # Migrate inventory files
  echo -e "${YELLOW}Migrating inventory files...${NC}"
  cp "$PROJECT_ROOT/ansible/inventory/group_vars/all.yml" "$NEW_DIR/deploy/ansible/inventory/"
  cp "$PROJECT_ROOT/ansible/inventory/group_vars/osint_servers.yml" "$NEW_DIR/deploy/ansible/inventory/"
  cp "$PROJECT_ROOT/ansible/inventory/host_vars/osint_server.yml" "$NEW_DIR/deploy/ansible/inventory/"
  cp "$PROJECT_ROOT/ansible/inventory/hosts.yml.template" "$NEW_DIR/deploy/ansible/inventory/"
  
  # Migrate playbooks
  echo -e "${YELLOW}Migrating playbooks...${NC}"
  cp "$PROJECT_ROOT/ansible/playbooks/"*.yml "$NEW_DIR/deploy/ansible/playbooks/"
  
  # Create consolidated roles
  echo -e "${YELLOW}Consolidating roles...${NC}"
  
  # Base role (system, security, networking)
  mkdir -p "$NEW_DIR/deploy/ansible/roles/base/tasks"
  mkdir -p "$NEW_DIR/deploy/ansible/roles/base/templates"
  mkdir -p "$NEW_DIR/deploy/ansible/roles/base/handlers"
  
  # Combine base tasks
  cat > "$NEW_DIR/deploy/ansible/roles/base/tasks/main.yml" << EOF
---
# Base role tasks
- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 86400  # 24 hours

- name: Install base dependencies
  apt:
    name: "{{ system_packages }}"
    state: present

- name: Configure timezone
  timezone:
    name: "{{ timezone | default('UTC') }}"

- name: Create OSINT directory structure
  file:
    path: "{{ item }}"
    state: directory
    mode: 0755
  loop:
    - /opt/osint
    - /opt/osint/tools
    - /opt/osint/data
    - /opt/osint/scripts
    - /opt/osint/logs
    - /opt/osint/containers
    - /opt/osint/secure_creds

# Include security tasks
- import_tasks: security.yml

# Include network tasks
- import_tasks: network.yml

# Include container tasks
- import_tasks: containers.yml
EOF
  
  # Extract security tasks from security_enhancements role
  cat "$PROJECT_ROOT/ansible/roles/security_enhancements/tasks/main.yml" > "$NEW_DIR/deploy/ansible/roles/base/tasks/security.yml"
  
  # Extract network tasks from networking role
  if [ -f "$PROJECT_ROOT/ansible/roles/networking/tasks/main.yml" ]; then
    cat "$PROJECT_ROOT/ansible/roles/networking/tasks/main.yml" > "$NEW_DIR/deploy/ansible/roles/base/tasks/network.yml"
  else
    # Create a placeholder
    echo "---" > "$NEW_DIR/deploy/ansible/roles/base/tasks/network.yml"
  fi
  
  # Extract container tasks from containerd role
  cat "$PROJECT_ROOT/ansible/roles/containerd/tasks/main.yml" > "$NEW_DIR/deploy/ansible/roles/base/tasks/containers.yml"
  
  # Copy templates
  cp "$PROJECT_ROOT/ansible/roles/containerd/templates/"* "$NEW_DIR/deploy/ansible/roles/base/templates/" 2>/dev/null || true
  cp "$PROJECT_ROOT/ansible/roles/networking/templates/"* "$NEW_DIR/deploy/ansible/roles/base/templates/" 2>/dev/null || true
  cp "$PROJECT_ROOT/ansible/roles/security/templates/"* "$NEW_DIR/deploy/ansible/roles/base/templates/" 2>/dev/null || true
  
  # Create handlers
  cat > "$NEW_DIR/deploy/ansible/roles/base/handlers/main.yml" << EOF
---
# Handlers for base role
- name: Restart containerd
  systemd:
    name: containerd
    state: restarted
    enabled: yes
    daemon_reload: yes

- name: Restart networking
  service:
    name: networking
    state: restarted

- name: Restart SSH
  service:
    name: ssh
    state: restarted

- name: Restart fail2ban
  service:
    name: fail2ban
    state: restarted

- name: Restart firewall
  service:
    name: ufw
    state: restarted
EOF
  
  # OSINT role (tool deployment, data correlation)
  mkdir -p "$NEW_DIR/deploy/ansible/roles/osint/tasks"
  mkdir -p "$NEW_DIR/deploy/ansible/roles/osint/templates"
  mkdir -p "$NEW_DIR/deploy/ansible/roles/osint/handlers"
  
  # Combine OSINT tasks
  cat > "$NEW_DIR/deploy/ansible/roles/osint/tasks/main.yml" << EOF
---
# OSINT tools deployment tasks
- name: Install OSINT tool dependencies
  apt:
    name:
      - git
      - python3
      - python3-pip
      - python3-venv
      - nmap
      - whois
      - dnsutils
      - jq
    state: present

# Include data correlation tasks
- import_tasks: data_correlation.yml

# Include container tools tasks
- import_tasks: containers.yml
EOF
  
  # Extract data correlation tasks
  if [ -f "$PROJECT_ROOT/ansible/roles/data_correlation/tasks/main.yml" ]; then
    cat "$PROJECT_ROOT/ansible/roles/data_correlation/tasks/main.yml" > "$NEW_DIR/deploy/ansible/roles/osint/tasks/data_correlation.yml"
  else
    # Create a placeholder
    echo "---" > "$NEW_DIR/deploy/ansible/roles/osint/tasks/data_correlation.yml"
  fi
  
  # Create container tools tasks
  cat > "$NEW_DIR/deploy/ansible/roles/osint/tasks/containers.yml" << EOF
---
# Container tools setup
- name: Create container data directories
  file:
    path: "{{ item }}"
    state: directory
    mode: 0755
  loop:
    - /opt/osint/containers/base
    - /opt/osint/containers/domain
    - /opt/osint/containers/network
    - /opt/osint/containers/identity
    - /opt/osint/containers/web
    - /opt/osint/containers/data

- name: Copy container definitions
  copy:
    src: "../core/containers/"
    dest: "/opt/osint/containers/"
    mode: 0755
    directory_mode: 0755

- name: Copy container management script
  copy:
    src: "../core/containers/manager.sh"
    dest: "/opt/osint/scripts/container_manager.sh"
    mode: 0755
EOF
  
  # Copy templates
  cp -r "$PROJECT_ROOT/ansible/roles/container_integration/templates/"* "$NEW_DIR/deploy/ansible/roles/osint/templates/" 2>/dev/null || true
  cp -r "$PROJECT_ROOT/ansible/roles/neo4j/templates/"* "$NEW_DIR/deploy/ansible/roles/osint/templates/" 2>/dev/null || true
  
  # Create handlers
  cat > "$NEW_DIR/deploy/ansible/roles/osint/handlers/main.yml" << EOF
---
# Handlers for OSINT role
- name: Restart container services
  command: /opt/osint/scripts/container_manager.sh restart

- name: Restart Neo4j
  command: /opt/osint/scripts/neo4j_init.sh
EOF
  
  echo -e "${GREEN}Ansible configuration migrated${NC}"
}

# Function to migrate tools
migrate_tools() {
  echo -e "${BLUE}Migrating tools...${NC}"
  
  # Create tools directory structure
  mkdir -p "$NEW_DIR/tools/domain"
  mkdir -p "$NEW_DIR/tools/network"
  mkdir -p "$NEW_DIR/tools/identity"
  mkdir -p "$NEW_DIR/tools/web"
  mkdir -p "$NEW_DIR/tools/data-correlation/python"
  
  # Migrate data correlation tools
  echo -e "${YELLOW}Migrating data correlation tools...${NC}"
  cp -r "$PROJECT_ROOT/tools/data-correlation/python/"* "$NEW_DIR/tools/data-correlation/python/" 2>/dev/null || true
  cp -r "$PROJECT_ROOT/tools/formats/"* "$NEW_DIR/tools/data-correlation/" 2>/dev/null || true
  
  # Create README files for tool categories
  for category in domain network identity web; do
    cat > "$NEW_DIR/tools/$category/README.md" << EOF
# OSINT Command Center - ${category^} Tools

This directory contains tools for ${category} analysis in the OSINT Command Center.

## Tools Included

- Coming soon...

## Usage

These tools are primarily used through the container system of OSINT Command Center.
See the documentation for more details on how to use them.
EOF
  done
  
  echo -e "${GREEN}Tools migrated${NC}"
}

# Function to migrate scripts
migrate_scripts() {
  echo -e "${BLUE}Migrating scripts...${NC}"
  
  # Copy scripts to the new structure
  cp "$PROJECT_ROOT/scripts/container_orchestration.sh" "$NEW_DIR/scripts/" 2>/dev/null || true
  cp "$PROJECT_ROOT/scripts/system_integration.sh" "$NEW_DIR/scripts/" 2>/dev/null || true
  
  # Copy terminal interface scripts
  cp -r "$PROJECT_ROOT/terminal_interface/"* "$NEW_DIR/ui/terminal/" 2>/dev/null || true
  
  echo -e "${GREEN}Scripts migrated${NC}"
}

# Function to migrate configs
migrate_configs() {
  echo -e "${BLUE}Migrating configuration files...${NC}"
  
  # Create config directories
  mkdir -p "$NEW_DIR/core/configs/security"
  mkdir -p "$NEW_DIR/core/configs/network"
  mkdir -p "$NEW_DIR/core/configs/tools"
  
  # Copy security configs
  cp "$PROJECT_ROOT/configs/safety/personal_security_tips.md" "$NEW_DIR/core/configs/security/" 2>/dev/null || true
  cp "$PROJECT_ROOT/configs/security/"* "$NEW_DIR/core/configs/security/" 2>/dev/null || true
  
  # Copy tool configs
  cp "$PROJECT_ROOT/configs/tools/"* "$NEW_DIR/core/configs/tools/" 2>/dev/null || true
  
  # Copy container configs
  cp "$PROJECT_ROOT/configs/containerd/config.toml" "$NEW_DIR/core/configs/network/" 2>/dev/null || true
  
  echo -e "${GREEN}Configuration files migrated${NC}"
}

# Main migration function
main() {
  echo -e "${BLUE}Starting OSINT Command Center migration...${NC}"
  
  # Ensure the new directory exists
  mkdir -p "$NEW_DIR"
  
  # Create directory structure
  create_directory_structure
  
  # Migrate components
  migrate_ansible
  migrate_tools
  migrate_scripts
  migrate_configs
  
  echo -e "${GREEN}Migration completed successfully!${NC}"
  echo
  echo -e "${YELLOW}Next steps:${NC}"
  echo -e "1. Review the migrated files and update any path references"
  echo -e "2. Test the deployment process with the new structure"
  echo -e "3. Update documentation to reflect the new structure"
}

# Run the migration
main "$@"
