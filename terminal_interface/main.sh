#!/bin/bash

# OSINT Command Center Terminal Interface
# Main entry point for the mobile-friendly terminal UI

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Import modules
source /opt/osint/terminal_interface/helpers/input.sh
source /opt/osint/terminal_interface/helpers/display.sh
source /opt/osint/terminal_interface/helpers/validation.sh

# Import feature modules
source /opt/osint/terminal_interface/modules/domain.sh
source /opt/osint/terminal_interface/modules/network.sh
source /opt/osint/terminal_interface/modules/identity.sh
source /opt/osint/terminal_interface/modules/web.sh
source /opt/osint/terminal_interface/modules/vpn.sh
source /opt/osint/terminal_interface/modules/system.sh

# Configuration
DATA_DIR="/opt/osint/data"
SYSTEM_SCRIPT="/opt/osint/scripts/system_integration.sh"
CONTAINER_SCRIPT="/opt/osint/scripts/container_orchestration.sh"

# Function to check system readiness
check_system_readiness() {
  # Check if containers are running
  if ! sudo nerdctl ps | grep -q "osint-"; then
    echo -e "${YELLOW}Containers are not running. Starting them...${NC}"
    sudo $CONTAINER_SCRIPT start
  fi
  
  # Check data directory
  if [ ! -d "$DATA_DIR" ]; then
    echo -e "${YELLOW}Creating data directory...${NC}"
    sudo mkdir -p "$DATA_DIR"
  fi
}

# Main interface header
show_header() {
  clear
  
  # Get current system info
  vpn_status=$(sudo vpn status 2>/dev/null | grep -q "active" && echo "ACTIVE" || echo "INACTIVE")
  container_count=$(sudo nerdctl ps | grep "osint-" | wc -l)
  
  # Display header
  width=$(tput cols)
  title="OSINT COMMAND CENTER"
  
  # Center the title
  printf "%*s\n" $(( (width + ${#title}) / 2)) "$title"
  printf "%*s\n" $width | tr " " "="
  
  echo -e "VPN: ${vpn_status} | Containers: ${container_count} | $(date '+%Y-%m-%d %H:%M')"
  printf "%*s\n" $width | tr " " "-"
}

# Main menu
main_menu() {
  show_header
  
  echo -e "1. ${BLUE}[🌐]${NC} Domain Intelligence"
  echo -e "2. ${BLUE}[🔍]${NC} Network Scanning"
  echo -e "3. ${BLUE}[👤]${NC} Identity Research"
  echo -e "4. ${BLUE}[🕸️]${NC} Web Analysis"
  echo -e "5. ${BLUE}[🔒]${NC} Security & Privacy"
  echo -e "6. ${BLUE}[⚙️]${NC} System Controls"
  echo -e "7. ${BLUE}[📊]${NC} Data Correlation"
  echo -e "0. ${RED}[✖]${NC} Exit"
  echo ""
  
  read_input "Select option: " option validate_number
  
  case $option in
    1) domain_menu ;;
    2) network_menu ;;
    3) identity_menu ;;
    4) web_menu ;;
    5) security_menu ;;
    6) system_menu ;;
    7) data_correlation_menu ;;
    0) exit_menu ;;
    *) main_menu ;;
  esac
}

# Data correlation menu
data_correlation_menu() {
  show_header
  echo -e "${BLUE}[📊] DATA CORRELATION${NC}"
  
  echo -e "1. Process Target Data"
  echo -e "2. Import to Neo4j"
  echo -e "3. Generate Visualization"
  echo -e "4. Generate Report"
  echo -e "5. Export Data"
  echo -e "9. Back to Main Menu"
  echo -e "0. Exit"
  echo ""
  
  read_input "Select option: " option validate_number
  
  case $option in
    1)
      # Process target data
      read_input "Enter target name: " target
      sudo /opt/osint/scripts/data_integration.sh process "$target"
      read -p "Press Enter to continue..."
      ;;
    2)
      # Import to Neo4j
      read_input "Enter target name: " target
      sudo /opt/osint/scripts/data_integration.sh import "$target"
      read -p "Press Enter to continue..."
      ;;
    3)
      # Generate visualization
      read_input "Enter target name: " target
      sudo nerdctl exec osint-data-storage python3 /opt/osint/tools/data_correlation/python/correlator.py -t "$target" -v
      read -p "Press Enter to continue..."
      ;;
    4)
      # Generate report
      read_input "Enter target name: " target
      sudo nerdctl exec osint-data-storage python3 /opt/osint/tools/data_correlation/python/correlator.py -t "$target" -r
      read -p "Press Enter to continue..."
      ;;
    5)
      # Export data
      read_input "Enter target name: " target
      read_input "Export type (json, csv, neo4j): " export_type
      sudo /opt/osint/scripts/data_integration.sh export "$target" "$export_type"
      read -p "Press Enter to continue..."
      ;;
    9)
      main_menu
      return
      ;;
    0)
      exit_menu
      ;;
    *)
      data_correlation_menu
      ;;
  esac
  
  data_correlation_menu
}

# Exit menu
exit_menu() {
  show_header
  echo -e "${RED}Are you sure you want to exit?${NC}"
  echo -e "1. Yes, exit"
  echo -e "2. No, return to main menu"
  echo ""
  
  read_input "Select option: " option validate_number
  
  case $option in
    1)
      clear
      echo -e "${GREEN}Thank you for using OSINT Command Center${NC}"
      exit 0
      ;;
    2)
      main_menu
      ;;
    *)
      exit_menu
      ;;
  esac
}

# Main application start
check_system_readiness
main_menu

# Loop back to main menu
while true; do
  main_menu
done