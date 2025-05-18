#!/bin/bash

# ui/terminal/modules/network.sh
# Network scanning module for OSINT Command Center Terminal Interface

# Network Module
# Handles network reconnaissance tasks

# Load helper functions
source "$SCRIPT_DIR/helpers/helpers.sh"

# Define directories
NETWORK_DATA_DIR="${DATA_DIR}/network"

# Container name for network scanning tools
NETWORK_CONTAINER="network"

# =====================================
# Network Scanning Functions
# =====================================

# Run network scan on target IP or domain
network_scan() {
  local target=""
  
  # Get target (IP or domain)
  read_input "Enter target IP or domain: " target
  
  # Validate target
  if ! validate_ip "$target" 2>/dev/null && ! validate_domain "$target" 2>/dev/null; then
    status_message error "Invalid target. Please enter a valid IP address or domain name."
    sleep 2
    return
  fi
  
  # Create target directory (sanitize for filesystem)
  local target_safe=$(echo "$target" | tr '/' '_')
  local target_dir="$NETWORK_DATA_DIR/$target_safe"
  sudo mkdir -p "$target_dir"
  
  section_header "Network Scan: $target"
  
  # Ask for scan type
  echo -e "1. ${BLUE}[🔍]${NC} Quick Scan (top 1000 ports)"
  echo -e "2. ${BLUE}[🔨]${NC} Full Scan (all ports, slower)"
  echo -e "3. ${BLUE}[💥]${NC} Comprehensive (all ports + service detection + scripts)"
  read_input "Select scan type: " scan_type validate_number
  
  # Ensure network container is running
  echo -e "${YELLOW}Starting network scanning container...${NC}"
  sudo $CONTAINER_MANAGER start $NETWORK_CONTAINER
  
  # Run scan
  case $scan_type in
    1)
      # Quick scan
      echo -e "${YELLOW}Running quick port scan...${NC}"
      cmd="rustscan -a $target --ulimit 5000 --batch-size 2500 --no-nmap -- -oX $NETWORK_DATA_DIR/$target_safe/quick_scan.xml"
      sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER $cmd &
      show_spinner $! "Scanning top 1000 ports..."
      scan_file="$target_dir/quick_scan.xml"
      ;;
    2)
      # Full scan
      echo -e "${YELLOW}Running full port scan...${NC}"
      cmd="rustscan -a $target --ulimit 5000 --batch-size 2500 --range 1-65535 --no-nmap -- -oX $NETWORK_DATA_DIR/$target_safe/full_scan.xml"
      sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER $cmd &
      show_spinner $! "Scanning all ports..."
      scan_file="$target_dir/full_scan.xml"
      ;;
    3)
      # Comprehensive scan
      echo -e "${YELLOW}Running comprehensive port scan...${NC}"
      cmd="rustscan -a $target --ulimit 5000 --batch-size 2500 --range 1-65535 --no-nmap -- -sV -sC -A -oX $NETWORK_DATA_DIR/$target_safe/comprehensive_scan.xml"
      sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER $cmd &
      show_spinner $! "Scanning all ports with service detection and scripts..."
      scan_file="$target_dir/comprehensive_scan.xml"
      ;;
    *)
      status_message error "Invalid selection"
      sleep 2
      return
      ;;
  esac
  
  # Process results
  if sudo test -f "$scan_file"; then
    # Parse XML to extract open ports
    echo -e "${YELLOW}Extracting scan results...${NC}"
    
    # Use xmllint or grep to parse results
    if command -v xmllint >/dev/null 2>&1; then
      open_ports=$(sudo xmllint --xpath "//port[@state='open']/@portid" "$scan_file" 2>/dev/null | \
                   grep -oP 'portid="\K[0-9]+' | sort -n | tr '\n' ' ')
      port_count=$(echo "$open_ports" | wc -w)
    else
      open_ports=$(sudo grep -oP 'portid="\K[0-9]+(?=".+state="open")' "$scan_file" | sort -n | tr '\n' ' ')
      port_count=$(echo "$open_ports" | wc -w)
    fi
    
    echo
    status_message success "Scan completed"
    echo
    echo -e "${BLUE}Results for $target:${NC}"
    echo -e "Found $port_count open ports"
    echo
    
    if [ $port_count -gt 0 ]; then
      echo -e "${YELLOW}Open ports:${NC}"
      
      # Generate a readable report
      if command -v xmllint >/dev/null 2>&1; then
        # Using xmllint for better parsing
        sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "xsltproc $NETWORK_DATA_DIR/$target_safe/$(basename "$scan_file") -o $NETWORK_DATA_DIR/$target_safe/scan_report.html"
        
        # Extract service info
        sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "grep -A2 'state=\"open\"' $NETWORK_DATA_DIR/$target_safe/$(basename "$scan_file") | grep -E 'portid=|service name=' | tr '\n' ' ' | sed 's/<port/\n<port/g' | head -10" | \
          sed -E 's/.*portid="([0-9]+)".*name="([^"]*)".*product="([^"]*)".*/Port \1: \2 (\3)/g; s/.*portid="([0-9]+)".*name="([^"]*)".*/Port \1: \2/g'
      else
        # Fallback to simpler parsing
        for port in $open_ports; do
          service=$(sudo grep -A3 "portid=\"$port\".*state=\"open\"" "$scan_file" | grep "service name=" | sed -E 's/.*name="([^"]*)".*product="([^"]*)".*/\1 (\2)/g; s/.*name="([^"]*)".*/\1/g')
          if [ -n "$service" ]; then
            echo "Port $port: $service"
          else
            echo "Port $port: unknown"
          fi
        done | head -10
      fi
      
      if [ $port_count -gt 10 ]; then
        echo "... (more ports in scan results)"
      fi
    else
      echo -e "${YELLOW}No open ports found${NC}"
    fi
    
    # Generate HTML report if xsltproc is available
    if sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER which xsltproc >/dev/null 2>&1; then
      sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "xsltproc /opt/osint/data/network/$target_safe/$(basename "$scan_file") -o /opt/osint/data/network/$target_safe/scan_report.html"
      echo
      echo -e "${BLUE}HTML report generated:${NC} $target_dir/scan_report.html"
    fi
  else
    status_message error "Scan failed or no results found"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Perform service detection
service_detection() {
  local target=""
  
  # Get target
  read_input "Enter target IP or domain: " target
  
  # Validate target
  if ! validate_ip "$target" 2>/dev/null && ! validate_domain "$target" 2>/dev/null; then
    status_message error "Invalid target. Please enter a valid IP address or domain name."
    sleep 2
    return
  fi
  
  # Create target directory
  local target_safe=$(echo "$target" | tr '/' '_')
  local target_dir="$NETWORK_DATA_DIR/$target_safe"
  sudo mkdir -p "$target_dir"
  
  section_header "Service Detection: $target"
  
  # Ask for ports
  read_input "Enter ports to scan (e.g., 22,80,443) or leave empty for top 1000: " ports
  
  # Format port parameter
  local port_param=""
  if [[ -n "$ports" ]]; then
    port_param="-p $ports"
  fi
  
  # Ensure network container is running
  echo -e "${YELLOW}Starting network scanning container...${NC}"
  sudo $CONTAINER_MANAGER start $NETWORK_CONTAINER
  
  # Run nmap service detection
  echo -e "${YELLOW}Running service version detection...${NC}"
  cmd="nmap $port_param -sV -sC $target -oX $NETWORK_DATA_DIR/$target_safe/service_detection.xml"
  sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER $cmd &
  show_spinner $! "Detecting service versions..."
  
  # Process results
  if sudo test -f "$target_dir/service_detection.xml"; then
    echo
    status_message success "Service detection completed"
    echo
    
    # Extract service info
    echo -e "${BLUE}Detected services on $target:${NC}"
    echo
    
    if command -v xmllint >/dev/null 2>&1; then
      # Using xmllint for better parsing if available
      sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "grep -A5 'state=\"open\"' $NETWORK_DATA_DIR/$target_safe/service_detection.xml | grep -E 'portid=|service name=|product=|version=' | tr '\n' ' ' | sed 's/<port/\n<port/g'" | \
        sed -E 's/.*portid="([^"]+)".*name="([^"]+)".*product="([^"]*)".*version="([^"]*)".*/Port \1: \2 \3 \4/g; s/.*portid="([^"]+)".*name="([^"]+)".*/Port \1: \2/g' | \
        sort -n -k2 -t ' '
    else
      # Fallback to simpler parsing
      sudo grep -A5 'state="open"' "$target_dir/service_detection.xml" | \
        grep -E 'portid=|service name=' | \
        tr '\n' ' ' | \
        sed 's/<port/\n<port/g' | \
        grep 'state="open"' | \
        sed -E 's/.*portid="([^"]+)".*name="([^"]+)".*product="([^"]*)".*version="([^"]*)".*/Port \1: \2 \3 \4/g; s/.*portid="([^"]+)".*name="([^"]+)".*/Port \1: \2/g' | \
        sort -n -k2 -t ' '
    fi
    
    # Generate HTML report if xsltproc is available
    if sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER which xsltproc >/dev/null 2>&1; then
      sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "xsltproc $NETWORK_DATA_DIR/$target_safe/service_detection.xml -o $NETWORK_DATA_DIR/$target_safe/service_report.html"
      echo
      echo -e "${BLUE}HTML report generated:${NC} $target_dir/service_report.html"
    fi
  else
    status_message error "Service detection failed or no results found"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Perform network reconnaissance
network_recon() {
  local target=""
  
  # Get target network range
  read_input "Enter target network range (e.g., 192.168.1.0/24): " target validate_ip required
  
  # Create target directory
  local target_safe=$(echo "$target" | tr '/' '_')
  local target_dir="$NETWORK_DATA_DIR/$target_safe"
  sudo mkdir -p "$target_dir"
  
  section_header "Network Reconnaissance: $target"
  
  # Ensure network container is running
  echo -e "${YELLOW}Starting network scanning container...${NC}"
  sudo $CONTAINER_MANAGER start $NETWORK_CONTAINER
  
  # Run host discovery
  echo -e "${YELLOW}Running host discovery...${NC}"
  cmd="nmap -sn $target -oX $NETWORK_DATA_DIR/$target_safe/host_discovery.xml"
  sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER $cmd &
  show_spinner $! "Discovering hosts on the network..."
  
  # Process results
  if sudo test -f "$target_dir/host_discovery.xml"; then
    echo
    status_message success "Host discovery completed"
    echo
    
    # Extract host info
    if command -v xmllint >/dev/null 2>&1; then
      # Using xmllint for better parsing if available
      live_hosts=$(sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "grep -A1 \"status state=\\\"up\\\"\" $NETWORK_DATA_DIR/$target_safe/host_discovery.xml | grep \"addr=\" | sed -E 's/.*addr=\"([^\"]+)\".*/\1/g'")
    else
      # Fallback to simpler parsing
      live_hosts=$(sudo grep -A1 "status state=\"up\"" "$target_dir/host_discovery.xml" | \
                  grep "addr=" | \
                  sed -E 's/.*addr="([^"]+)".*/\1/g')
    fi
    
    # Count hosts
    host_count=$(echo "$live_hosts" | wc -l)
    
    echo -e "${BLUE}Network reconnaissance results for $target:${NC}"
    echo -e "Found $host_count live hosts"
    echo
    
    if [ $host_count -gt 0 ]; then
      echo -e "${YELLOW}Live hosts:${NC}"
      echo "$live_hosts" | head -20
      
      if [ $host_count -gt 20 ]; then
        echo "... (more hosts in scan results)"
      fi
      
      # Save to file
      echo "$live_hosts" | sudo tee "$target_dir/live_hosts.txt" > /dev/null
      
      # Ask to perform service scan on discovered hosts
      echo
      read -p "Would you like to perform a service scan on these hosts? (y/N): " perform_service_scan
      
      if [[ "$perform_service_scan" == "y" || "$perform_service_scan" == "Y" ]]; then
        echo -e "${YELLOW}Running service scan on live hosts...${NC}"
        # Prepare comma-separated list of hosts
        live_hosts_param=$(echo "$live_hosts" | tr '\n' ',' | sed 's/,$//')
        
        cmd="nmap -sV -sC -oX $NETWORK_DATA_DIR/$target_safe/service_scan.xml $live_hosts_param"
        sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER $cmd &
        show_spinner $! "Scanning services on live hosts..."
        
        # Process service scan results
        if sudo test -f "$target_dir/service_scan.xml"; then
          status_message success "Service scan completed"
          echo
          echo -e "${BLUE}Notable services:${NC}"
          
          # Extract interesting services (web servers, SSH, etc.)
          sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "grep -A5 -E 'service name=\"http|service name=\"ssh|service name=\"ftp|service name=\"smtp|service name=\"dns' $NETWORK_DATA_DIR/$target_safe/service_scan.xml | grep -E 'addr=|portid=|service name=' | tr '\n' ' ' | sed 's/<host/\n<host/g' | grep 'state=\"open\"' | sed -E 's/.*addr=\"([^\"]+)\".*portid=\"([^\"]+)\".*name=\"([^\"]+)\".*/Host \1:\tPort \2 (\3)/g' | sort | head -20"
          
          # Generate HTML report if xsltproc is available
          if sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER which xsltproc >/dev/null 2>&1; then
            sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "xsltproc $NETWORK_DATA_DIR/$target_safe/service_scan.xml -o $NETWORK_DATA_DIR/$target_safe/network_services.html"
            echo
            echo -e "${BLUE}HTML report generated:${NC} $target_dir/network_services.html"
          fi
        else
          status_message error "Service scan failed or no results found"
        fi
      fi
    else
      echo -e "${YELLOW}No live hosts found${NC}"
    fi
  else
    status_message error "Host discovery failed or no results found"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Perform vulnerability scanning
vulnerability_scan() {
  local target=""
  
  # Get target
  read_input "Enter target IP or domain: " target
  
  # Validate target
  if ! validate_ip "$target" 2>/dev/null && ! validate_domain "$target" 2>/dev/null; then
    status_message error "Invalid target. Please enter a valid IP address or domain name."
    sleep 2
    return
  fi
  
  # Create target directory
  local target_safe=$(echo "$target" | tr '/' '_')
  local target_dir="$NETWORK_DATA_DIR/$target_safe"
  sudo mkdir -p "$target_dir"
  
  section_header "Vulnerability Scan: $target"
  
  # Warn about potential alerts
  echo -e "${RED}Warning: This scan may trigger IDS/IPS alerts${NC}"
  echo
  
  read -p "Do you want to continue? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    status_message warning "Scan aborted"
    sleep 2
    return
  fi
  
  # Ensure network container is running
  echo -e "${YELLOW}Starting network scanning container...${NC}"
  sudo $CONTAINER_MANAGER start $NETWORK_CONTAINER
  
  # Run nmap with vulnerability scripts
  echo -e "${YELLOW}Running vulnerability scan...${NC}"
  cmd="nmap -sV --script vuln $target -oX $NETWORK_DATA_DIR/$target_safe/vuln_scan.xml"
  sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER $cmd &
  show_spinner $! "Scanning for vulnerabilities..."
  
  # Process results
  if sudo test -f "$target_dir/vuln_scan.xml"; then
    echo
    status_message success "Vulnerability scan completed"
    echo
    
    # Extract vulnerability information
    echo -e "${BLUE}Potential vulnerabilities for $target:${NC}"
    echo
    
    # Extract script output with vulnerabilities
    sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "grep -A10 \"id=\\\"vuln\" $NETWORK_DATA_DIR/$target_safe/vuln_scan.xml | grep -E 'id=\\\"[^\\\"]*\\\"|output=' | tr '\n' ' ' | sed 's/<script/\n<script/g' | grep 'output=' | sed -E 's/.*id=\"([^\"]+)\".*output=\"([^\"]+)\".*/\1: \2/g' | sed -E 's/&lt;/</g' | sed -E 's/&gt;/>/g' | sed -E 's/&quot;/\"/g' | head -20"
    
    # Generate HTML report if xsltproc is available
    if sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER which xsltproc >/dev/null 2>&1; then
      sudo $CONTAINER_MANAGER exec $NETWORK_CONTAINER bash -c "xsltproc $NETWORK_DATA_DIR/$target_safe/vuln_scan.xml -o $NETWORK_DATA_DIR/$target_safe/vuln_report.html"
      echo
      echo -e "${BLUE}HTML report generated:${NC} $target_dir/vuln_report.html"
    fi
  else
    status_message error "Vulnerability scan failed or no results found"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Export network data
export_network_data() {
  # Check if any network scans have been performed
  if ! sudo test -d "$NETWORK_DATA_DIR" || [ -z "$(sudo ls -A "$NETWORK_DATA_DIR" 2>/dev/null)" ]; then
    status_message error "No network data available for export"
    sleep 2
    return
  fi
  
  # List available targets
  section_header "Export Network Data"
  echo -e "${BLUE}Available targets:${NC}"
  echo
  
  # Get list of targets
  local targets=$(sudo ls -1 "$NETWORK_DATA_DIR")
  local target_count=$(echo "$targets" | wc -l)
  local target_array=($targets)
  
  # Display targets with numbers
  for i in "${!target_array[@]}"; do
    echo -e "$((i+1)). ${target_array[$i]}"
  done
  echo
  
  # Select target
  read_input "Select target (1-$target_count): " target_idx validate_number
  
  if [[ "$target_idx" -ge 1 && "$target_idx" -le "$target_count" ]]; then
    local selected_target="${target_array[$((target_idx-1))]}"
    local target_dir="$NETWORK_DATA_DIR/$selected_target"
    
    # Create export directory
    local export_dir="$DATA_DIR/exports"
    sudo mkdir -p "$export_dir"
    
    # Export filename with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="$export_dir/${selected_target}_network_${timestamp}.tar.gz"
    
    # Create archive
    echo -e "${YELLOW}Creating export archive...${NC}"
    sudo tar -czf "$export_file" -C "$NETWORK_DATA_DIR" "$selected_target"
    
    if [ $? -eq 0 ]; then
      status_message success "Network data exported to $export_file"
      echo
      echo -e "${BLUE}Export contains:${NC}"
      sudo tar -tzf "$export_file" | grep -v "/$" | head -10
      
      # Show more info if the archive contains more than 10 files
      file_count=$(sudo tar -tzf "$export_file" | grep -v "/$" | wc -l)
      if [ "$file_count" -gt 10 ]; then
        echo "... and $((file_count - 10)) more files"
      fi
    else
      status_message error "Failed to create export archive"
    fi
  else
    status_message error "Invalid selection"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Network scanning menu
network_menu() {
  show_header
  echo -e "${BLUE}[🔍] NETWORK SCANNING${NC}"
  echo -e "1. Port Scan (Single Host)"
  echo -e "2. Service Detection"
  echo -e "3. Network Reconnaissance"
  echo -e "4. Vulnerability Scanning"
  echo -e "5. Export Network Data"
  echo -e "9. Back to Main Menu"
  echo -e "0. Exit"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1) network_scan ;;
    2) service_detection ;;
    3) network_recon ;;
    4) vulnerability_scan ;;
    5) export_network_data ;;
    9) return 0 ;;
    0) exit 0 ;;
    *) 
      status_message error "Invalid option"
      sleep 1
      ;;
  esac
  
  # Return to network menu after function completes
  network_menu
  return 0
}