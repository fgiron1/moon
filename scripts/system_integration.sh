#!/bin/bash

# OSINT Command Center System Integration
# Integrates all components of the OSINT system

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: This script must be run as root${NC}"
  exit 1
fi

# Function to check system status
check_system() {
  echo -e "\n${BLUE}=== OSINT System Status ===${NC}"
  
  # Check container status
  echo -e "\n${YELLOW}Container Status:${NC}"
  /opt/osint/scripts/container_orchestration.sh status
  
  # Check network status
  echo -e "\n${YELLOW}Network Status:${NC}"
  ip a | grep -E "(osint|eth|wlan|usb)"
  
  # Check storage
  echo -e "\n${YELLOW}Storage Status:${NC}"
  df -h /opt/osint/data
  
  # Check services
  echo -e "\n${YELLOW}Service Status:${NC}"
  systemctl status containerd --no-pager
  
  # Check Neo4j
  echo -e "\n${YELLOW}Neo4j Status:${NC}"
  if nerdctl ps | grep -q "osint-data-storage"; then
    curl -s http://localhost:7474 > /dev/null && echo -e "${GREEN}Neo4j web interface is accessible${NC}" || echo -e "${RED}Neo4j web interface is not accessible${NC}"
  else
    echo -e "${RED}Neo4j container is not running${NC}"
  fi
}

# Function to initialize system
init_system() {
  echo -e "${YELLOW}Initializing OSINT Command Center...${NC}"
  
  # Ensure data directories exist
  mkdir -p /opt/osint/data/{targets,standardized,exports,reports,neo4j}
  
  # Start containers
  echo -e "${YELLOW}Starting containers...${NC}"
  /opt/osint/scripts/container_orchestration.sh start
  
  # Initialize Neo4j
  echo -e "${YELLOW}Initializing Neo4j...${NC}"
  /opt/osint/scripts/neo4j_init.sh
  
  # Set up network routing
  echo -e "${YELLOW}Setting up network...${NC}"
  /opt/osint/scripts/container_routes.sh reset
  
  echo -e "${GREEN}System initialization complete${NC}"
}

# Function to update system
update_system() {
  echo -e "${YELLOW}Updating OSINT Command Center...${NC}"
  
  # Update system packages
  apt update && apt upgrade -y
  
  # Update container images
  /opt/osint/scripts/container_orchestration.sh rebuild
  
  # Update Python dependencies
  pip3 install --upgrade py2neo pandas networkx matplotlib pyyaml ipaddress
  
  echo -e "${GREEN}System update complete${NC}"
}

# Function to backup system
backup_system() {
  echo -e "${YELLOW}Backing up OSINT Command Center...${NC}"
  
  # Create timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  backup_dir="/opt/osint/backups/system_$timestamp"
  
  # Create backup directory
  mkdir -p "$backup_dir"
  
  # Backup configuration
  cp -r /opt/osint/containers "$backup_dir/containers"
  
  # Backup Neo4j (export database)
  if nerdctl ps | grep -q "osint-data-storage"; then
    nerdctl exec osint-data-storage neo4j-admin dump --database=neo4j --to=/opt/osint/data/neo4j/neo4j-backup-$timestamp.dump
    cp /opt/osint/data/neo4j/neo4j-backup-$timestamp.dump "$backup_dir/"
  fi
  
  # Create archive
  tar -czf "/opt/osint/backups/osint_system_backup_$timestamp.tar.gz" -C "$backup_dir" .
  rm -rf "$backup_dir"
  
  echo -e "${GREEN}System backup completed: /opt/osint/backups/osint_system_backup_$timestamp.tar.gz${NC}"
}

# Check command
case "$1" in
  status)
    check_system
    ;;
  init)
    init_system
    ;;
  update)
    update_system
    ;;
  backup)
    backup_system
    ;;
  *)
    echo -e "${BLUE}OSINT System Integration${NC}"
    echo -e "Usage: $0 {status|init|update|backup}"
    echo -e "  status  - Check system status"
    echo -e "  init    - Initialize system"
    echo -e "  update  - Update system components"
    echo -e "  backup  - Backup system configuration"
    exit 1
    ;;
esac

exit 0