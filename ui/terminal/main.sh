#!/bin/bash

# ui/terminal/main.sh
# Main entry point for OSINT Command Center Terminal Interface

# Load environment variables
if [ -f "$PWD/../../.env" ]; then
    source "$PWD/../../.env"
elif [ -f "/etc/osint/.env" ]; then
    source "/etc/osint/.env"
fi

# Set defaults if not defined in .env
export DATA_DIR="${DATA_DIR:-/opt/osint/data}"
export LOG_DIR="${LOG_DIR:-/opt/osint/logs}"

# Define module data directories
export WEB_DATA_DIR="$DATA_DIR/web"
export NETWORK_DATA_DIR="$DATA_DIR/network"
export IDENTITY_DATA_DIR="$DATA_DIR/identity"
export DOMAIN_DATA_DIR="$DATA_DIR/domain"

# Ensure all required directories exist
mkdir -p "$DATA_DIR" "$LOG_DIR" "$WEB_DATA_DIR" "$NETWORK_DATA_DIR" "$IDENTITY_DATA_DIR" "$DOMAIN_DATA_DIR"

# Set proper permissions
chmod -R 750 "$DATA_DIR"
chmod -R 750 "$LOG_DIR"

# Log environment settings
log_message "Starting OSINT Terminal with DATA_DIR=$DATA_DIR and LOG_DIR=$LOG_DIR"

# Configuration
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
MODULES_DIR="$SCRIPT_DIR/modules"
HELPERS_DIR="$SCRIPT_DIR/helpers"

# Load helper functions
source "$HELPERS_DIR/common.sh"

# Import modules dynamically
for module in "$MODULES_DIR"/*.sh; do
  if [ -f "$module" ]; then
    source "$module"
  fi
done

# System scripts
NETWORK_MANAGER="/opt/osint/core/network/manager.sh"
CONTAINER_MANAGER="/opt/osint/core/containers/manager.sh"
SYSTEM_MANAGER="/opt/osint/scripts/system.sh"
SECURITY_MANAGER="/opt/osint/core/security/manager.sh"

# =====================================
# System Status Functions
# =====================================

# Check system readiness
check_system_readiness() {
  # Check if containers are running
  if ! sudo $CONTAINER_MANAGER list | grep -q "Running"; then
    echo -e "${YELLOW}Containers are not running. Starting essential containers...${NC}"
    sudo $CONTAINER_MANAGER start data
  fi
  
  # Check data directory
  if [ ! -d "$DATA_DIR" ]; then
    echo -e "${YELLOW}Creating data directory...${NC}"
    sudo mkdir -p "$DATA_DIR"
    sudo mkdir -p "$DATA_DIR/targets" "$DATA_DIR/exports" "$DATA_DIR/reports"
  fi
  
  # Check network 
  if ! sudo $NETWORK_MANAGER status | grep -q "Container bridge" 2>/dev/null; then
    echo -e "${YELLOW}Setting up container network...${NC}"
    sudo $NETWORK_MANAGER containers eth0
  fi
}

# =====================================
# Menu Functions
# =====================================

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
    1) domain_menu || main_menu ;;
    2) network_menu || main_menu ;;
    3) identity_menu || main_menu ;;
    4) web_menu || main_menu ;;
    5) security_menu || main_menu ;;
    6) system_menu || main_menu ;;
    7) data_correlation_menu || main_menu ;;
    0) exit_menu ;;
    *) main_menu ;;
  esac
}

# Data correlation menu
data_correlation_menu() {
  show_header
  echo -e "${BLUE}[📊] DATA CORRELATION${NC}"
  
  echo -e "1. Analyze Target Data"
  echo -e "2. Import to Neo4j Database"
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
      
      # Check if target exists
      if [ ! -d "$DATA_DIR/targets/$target" ]; then
        status_message warning "Target '$target' does not exist."
        read -p "Would you like to create it? (y/N): " create
        if [[ "$create" =~ ^[Yy]$ ]]; then
          sudo mkdir -p "$DATA_DIR/targets/$target"
          status_message success "Created target directory."
        else
          status_message error "Operation cancelled."
          sleep 1
          data_correlation_menu
          return
        fi
      fi
      
      # Start the data container if not running
      sudo $CONTAINER_MANAGER start data
      
      # Run the data correlation tool
      sudo $CONTAINER_MANAGER exec data python3 /opt/osint/tools/data-correlation/correlator.py -t "$target" --data-dir /opt/osint/data
      
      read -p "Press Enter to continue..."
      ;;
    2)
      # Import to Neo4j
      read_input "Enter target name: " target
      
      # Check if target exists
      if [ ! -d "$DATA_DIR/targets/$target" ]; then
        status_message error "Target '$target' does not exist."
        sleep 1
        data_correlation_menu
        return
      fi
      
      # Start the data container if not running
      sudo $CONTAINER_MANAGER start data
      
      # Run the import tool
      sudo $CONTAINER_MANAGER exec data python3 /opt/osint/tools/data-correlation/import_tool.py -t "$target" --to-neo4j
      
      read -p "Press Enter to continue..."
      ;;
    3)
      # Generate visualization
      read_input "Enter target name: " target
      
      # Check if standardized data exists
      if [ ! -d "$DATA_DIR/standardized/$target" ]; then
        status_message error "No standardized data found for '$target'."
        status_message info "Please run 'Analyze Target Data' first."
        sleep 2
        data_correlation_menu
        return
      fi
      
      # Start the data container if not running
      sudo $CONTAINER_MANAGER start data
      
      # Run the visualization tool
      sudo $CONTAINER_MANAGER exec data python3 /opt/osint/tools/data-correlation/correlator.py -t "$target" --visualize
      
      status_message success "Visualization generated"
      echo -e "You can find the visualization in ${DATA_DIR}/reports/${target}/"
      
      read -p "Press Enter to continue..."
      ;;
    4)
      # Generate report
      read_input "Enter target name: " target
      
      # Check if standardized data exists
      if [ ! -d "$DATA_DIR/standardized/$target" ]; then
        status_message error "No standardized data found for '$target'."
        status_message info "Please run 'Analyze Target Data' first."
        sleep 2
        data_correlation_menu
        return
      fi
      
      # Start the data container if not running
      sudo $CONTAINER_MANAGER start data
      
      # Run the report generator
      sudo $CONTAINER_MANAGER exec data python3 /opt/osint/tools/data-correlation/report_generator.py --target "$target" --output "$DATA_DIR/reports/$target/report-$(date +%Y%m%d-%H%M%S)" --format markdown
      
      status_message success "Report generated"
      echo -e "You can find the report in ${DATA_DIR}/reports/${target}/"
      
      read -p "Press Enter to continue..."
      ;;
    5)
      # Export data
      read_input "Enter target name: " target
      
      # Check if standardized data exists
      if [ ! -d "$DATA_DIR/standardized/$target" ]; then
        status_message error "No standardized data found for '$target'."
        status_message info "Please run 'Analyze Target Data' first."
        sleep 2
        data_correlation_menu
        return
      fi
      
      # Select export format
      echo -e "${BLUE}Select export format:${NC}"
      echo -e "1. JSON"
      echo -e "2. CSV"
      echo -e "3. Neo4j Dump"
      read_input "Select format: " format_option validate_number
      
      case $format_option in
        1) format="json" ;;
        2) format="csv" ;;
        3) format="neo4j" ;;
        *) 
          status_message error "Invalid format selection."
          sleep 1
          data_correlation_menu
          return
          ;;
      esac
      
      # Create exports directory if it doesn't exist
      sudo mkdir -p "$DATA_DIR/exports/$target"
      
      # Export the data
      local timestamp=$(date +%Y%m%d-%H%M%S)
      local export_file="$DATA_DIR/exports/$target/${target}_${format}_${timestamp}"
      sudo $CONTAINER_MANAGER exec data python3 /opt/osint/tools/data-correlation/export_tool.py --target "$target" --format "$format" --output "$export_file"
      
      status_message success "Data exported"
      echo -e "You can find the exported data in ${DATA_DIR}/exports/${target}/"
      
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

# =====================================
# Interactive Mode and Command Mode
# =====================================

# Handle command mode
handle_command_mode() {
  local command="$1"
  shift
  
  case "$command" in
    domain)
      # Direct call to domain intelligence tools
      sudo $CONTAINER_MANAGER run domain "$@"
      ;;
    network)
      # Direct call to network scanning tools
      sudo $CONTAINER_MANAGER run network "$@"
      ;;
    identity)
      # Direct call to identity research tools
      sudo $CONTAINER_MANAGER run identity "$@"
      ;;
    web)
      # Direct call to web analysis tools
      sudo $CONTAINER_MANAGER run web "$@"
      ;;
    data)
      # Direct call to data correlation
      sudo $CONTAINER_MANAGER run data "$@"
      ;;
    system)
      # System control
      sudo $SYSTEM_MANAGER "$@"
      ;;
    network-control)
      # Network control
      sudo $NETWORK_MANAGER "$@"
      ;;
    container)
      # Container management
      sudo $CONTAINER_MANAGER "$@"
      ;;
    *)
      echo "Unknown command: $command"
      show_usage
      ;;
  esac
}

# Show command-line usage
show_usage() {
  echo "OSINT Command Center Terminal Interface"
  echo
  echo "Usage:"
  echo "  $0                     - Start interactive mode"
  echo "  $0 domain TOOL [ARGS]  - Run domain intelligence tool"
  echo "  $0 network TOOL [ARGS] - Run network scanning tool"
  echo "  $0 identity TOOL [ARGS] - Run identity research tool"
  echo "  $0 web TOOL [ARGS]     - Run web analysis tool"
  echo "  $0 data TOOL [ARGS]    - Run data correlation tool"
  echo "  $0 system COMMAND      - Run system control command"
  echo "  $0 network-control CMD - Run network control command"
  echo "  $0 container CMD       - Run container management command"
  echo
  echo "Examples:"
  echo "  $0 domain amass -d example.com"
  echo "  $0 network nmap -p 80 example.com"
  echo "  $0 identity sherlock username"
  echo "  $0 web nuclei -u example.com"
  echo "  $0 system status"
  echo "  $0 network-control status"
  echo "  $0 container list"
}

# =====================================
# Main Application Start
# =====================================

# Main entry point
main() {
  # Check for command mode
  if [ $# -gt 0 ]; then
    handle_command_mode "$@"
    exit $?
  fi
  
  # Interactive mode
  check_system_readiness
  main_menu
  
  # Loop back to main menu if needed
  while true; do
    main_menu
  done
}

# Run main function
main "$@"