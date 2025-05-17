#!/bin/bash

# Container orchestration script for OSINT Command Center
# Manages the lifecycle of all containers in the system

# Constants
CONTAINERS=(
  "osint-domain-intel"
  "osint-network-scan"
  "osint-identity-research"
  "osint-web-analysis"
  "osint-data-storage"
)

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

# Function to display status
status() {
  echo -e "\n${BLUE}=== OSINT Container Status ===${NC}"
  nerdctl ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Function to start all containers
start_all() {
  echo -e "${YELLOW}Starting all OSINT containers...${NC}"
  
  # Create container network if it doesn't exist
  if ! nerdctl network ls | grep -q "osint-network"; then
    echo -e "Creating osint-network..."
    nerdctl network create osint-network
  fi
  
  # Start each container
  for container in "${CONTAINERS[@]}"; do
    echo -e "Starting $container..."
    if nerdctl start "$container" 2>/dev/null; then
      echo -e "${GREEN}Container $container started${NC}"
    elif nerdctl ps -a | grep -q "$container"; then
      echo -e "${YELLOW}Container $container already started${NC}"
    else
      echo -e "${YELLOW}Container $container not found. Creating...${NC}"
      create_container "$container"
    fi
  done
  
  status
}

# Function to create a container
create_container() {
  local container=$1
  
  case "$container" in
    "osint-domain-intel")
      nerdctl run -d --name "$container" --network osint-network -v /opt/osint/data:/opt/osint/data osint-domain-intel:latest sleep infinity
      ;;
    "osint-network-scan")
      nerdctl run -d --name "$container" --network osint-network -v /opt/osint/data:/opt/osint/data osint-network-scan:latest sleep infinity
      ;;
    "osint-identity-research")
      nerdctl run -d --name "$container" --network osint-network -v /opt/osint/data:/opt/osint/data osint-identity-research:latest sleep infinity
      ;;
    "osint-web-analysis")
      nerdctl run -d --name "$container" --network osint-network -v /opt/osint/data:/opt/osint/data osint-web-analysis:latest sleep infinity
      ;;
    "osint-data-storage")
      nerdctl run -d --name "$container" --network osint-network \
        -v /opt/osint/data:/opt/osint/data \
        -v /opt/osint/data/neo4j/data:/data \
        -v /opt/osint/data/neo4j/logs:/logs \
        -v /opt/osint/data/neo4j/import:/import \
        -p 7474:7474 -p 7687:7687 \
        osint-data-storage:latest
      ;;
    *)
      echo -e "${RED}Unknown container: $container${NC}"
      return 1
      ;;
  esac
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Container $container created${NC}"
  else
    echo -e "${RED}Failed to create container $container${NC}"
    return 1
  fi
}

# Function to stop all containers
stop_all() {
  echo -e "${YELLOW}Stopping all OSINT containers...${NC}"
  
  for container in "${CONTAINERS[@]}"; do
    if nerdctl ps | grep -q "$container"; then
      echo -e "Stopping $container..."
      nerdctl stop "$container"
    else
      echo -e "${YELLOW}Container $container not running${NC}"
    fi
  done
  
  status
}

# Function to restart all containers
restart_all() {
  stop_all
  sleep 2
  start_all
}

# Function to rebuild all containers
rebuild_all() {
  echo -e "${YELLOW}Rebuilding all OSINT containers...${NC}"
  
  # Stop all containers first
  stop_all
  
  # Remove containers
  for container in "${CONTAINERS[@]}"; do
    if nerdctl ps -a | grep -q "$container"; then
      echo -e "Removing $container..."
      nerdctl rm "$container"
    fi
  done
  
  # Build base image first
  echo -e "Building base image..."
  nerdctl build -t osint-base:latest /opt/osint/containers/base
  
  # Build each container
  for container in "${CONTAINERS[@]}"; do
    container_dir=${container#osint-}
    if [[ -d "/opt/osint/containers/$container_dir" ]]; then
      echo -e "Building $container..."
      nerdctl build -t "$container:latest" "/opt/osint/containers/$container_dir"
    fi
  done
  
  # Create and start containers
  start_all
}

# Check command
case "$1" in
  start)
    start_all
    ;;
  stop)
    stop_all
    ;;
  restart)
    restart_all
    ;;
  status)
    status
    ;;
  rebuild)
    rebuild_all
    ;;
  *)
    echo -e "${BLUE}OSINT Container Orchestration${NC}"
    echo -e "Usage: $0 {start|stop|restart|status|rebuild}"
    echo -e "  start   - Start all containers"
    echo -e "  stop    - Stop all containers"
    echo -e "  restart - Restart all containers"
    echo -e "  status  - Show container status"
    echo -e "  rebuild - Rebuild and restart all containers"
    exit 1
    ;;
esac

exit 0