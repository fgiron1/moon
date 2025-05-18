#!/bin/bash

# ui/terminal/modules/domain.sh
# Domain intelligence module for OSINT Command Center Terminal Interface

# Container name for domain intelligence tools
DOMAIN_CONTAINER="domain"

# Directory for domain data
DOMAIN_DATA_DIR="$DATA_DIR/domain"

# =====================================
# Domain Intelligence Functions
# =====================================

# Run domain reconnaissance
domain_recon() {
  local domain=""
  
  # Get domain
  read_input "Enter domain to scan: " domain validate_domain required
  
  # Create target directory
  local target_dir="$DOMAIN_DATA_DIR/$domain"
  sudo mkdir -p "$target_dir"
  
  section_header "Domain Reconnaissance: $domain"
  
  # Ensure domain container is running
  echo -e "${YELLOW}Starting domain intelligence container...${NC}"
  sudo $CONTAINER_MANAGER start $DOMAIN_CONTAINER
  
  # Run amass in container for passive enumeration
  echo -e "${YELLOW}Running Amass passive scan...${NC}"
  amass_cmd="amass enum -passive -d $domain -o /opt/osint/data/domain/$domain/amass_passive.txt"
  sudo $CONTAINER_MANAGER exec $DOMAIN_CONTAINER $amass_cmd &
  show_spinner $! "Gathering passive reconnaissance data..."
  
  # Run subfinder in container for subdomain discovery
  echo -e "${YELLOW}Running Subfinder scan...${NC}"
  subfinder_cmd="subfinder -d $domain -o /opt/osint/data/domain/$domain/subfinder.txt"
  sudo $CONTAINER_MANAGER exec $DOMAIN_CONTAINER $subfinder_cmd &
  show_spinner $! "Discovering subdomains..."
  
  # Run dnsx in container for DNS resolution if available
  if sudo $CONTAINER_MANAGER exec $DOMAIN_CONTAINER which dnsx >/dev/null 2>&1; then
    echo -e "${YELLOW}Running DNS resolution...${NC}"
    dnsx_cmd="dnsx -l /opt/osint/data/domain/$domain/subfinder.txt -json -o /opt/osint/data/domain/$domain/dns_resolution.json"
    sudo $CONTAINER_MANAGER exec $DOMAIN_CONTAINER $dnsx_cmd &
    show_spinner $! "Resolving DNS records..."
  fi
  
  # Display results
  echo
  status_message success "Domain reconnaissance completed"
  echo
  echo -e "${BLUE}Found subdomains:${NC}"
  
  if sudo test -f "$target_dir/subfinder.txt"; then
    subdomain_count=$(sudo cat "$target_dir/subfinder.txt" | wc -l)
    echo -e "$subdomain_count subdomains discovered"
    sudo head -n 5 "$target_dir/subfinder.txt"
    
    if [ $subdomain_count -gt 5 ]; then
      echo "... (more results in $target_dir/subfinder.txt)"
    fi
  else
    echo "No subdomains found"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Run subdomain enumeration
subdomain_enum() {
  local domain=""
  
  # Get domain
  read_input "Enter domain for subdomain enumeration: " domain validate_domain required
  
  # Create target directory
  local target_dir="$DOMAIN_DATA_DIR/$domain"
  sudo mkdir -p "$target_dir"
  
  section_header "Subdomain Enumeration: $domain"
  
  # Ask for enumeration type
  echo -e "1. ${BLUE}[🔍]${NC} Passive (fast, no direct contact with target)"
  echo -e "2. ${BLUE}[🔨]${NC} Active (slower, directly queries target)"
  echo -e "3. ${BLUE}[💥]${NC} Aggressive (comprehensive, very noisy)"
  read_input "Select enumeration type: " enum_type validate_number
  
  # Ensure domain container is running
  echo -e "${YELLOW}Starting domain intelligence container...${NC}"
  sudo $CONTAINER_MANAGER start $DOMAIN_CONTAINER
  
  case $enum_type in
    1)
      # Passive enumeration
      echo -e "${YELLOW}Running passive subdomain enumeration...${NC}"
      cmd="subfinder -d $domain -o /opt/osint/data/domain/$domain/passive_subdomains.txt"
      sudo $CONTAINER_MANAGER exec $DOMAIN_CONTAINER $cmd &
      show_spinner $! "Gathering subdomain intelligence..."
      result_file="$target_dir/passive_subdomains.txt"
      ;;
    2)
      # Active enumeration
      echo -e "${YELLOW}Running active subdomain enumeration...${NC}"
      cmd="amass enum -active -d $domain -o /opt/osint/data/domain/$domain/active_subdomains.txt"
      sudo $CONTAINER_MANAGER exec $DOMAIN_CONTAINER $cmd &
      show_spinner $! "Actively enumerating subdomains..."
      result_file="$target_dir/active_subdomains.txt"
      ;;
    3)
      # Aggressive enumeration
      echo -e "${YELLOW}Running aggressive subdomain enumeration...${NC}"
      cmd="amass enum -active -brute -d $domain -o /opt/osint/data/domain/$domain/aggressive_subdomains.txt"
      sudo $CONTAINER_MANAGER exec $DOMAIN_CONTAINER $cmd &
      show_spinner $! "Aggressively enumerating subdomains..."
      result_file="$target_dir/aggressive_subdomains.txt"
      ;;
    *)
      status_message error "Invalid selection"
      sleep 2
      return
      ;;
  esac
  
  # Display results
  echo
  status_message success "Subdomain enumeration completed"
  echo
  
  if sudo test -f "$result_file"; then
    subdomain_count=$(sudo cat "$result_file" | wc -l)
    echo -e "$subdomain_count subdomains discovered"
    echo
    sudo head -n 10 "$result_file"
    
    if [ $subdomain_count -gt 10 ]; then
      echo "... (more results in $result_file)"
    fi
  else
    echo "No subdomains found"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Perform DNS analysis
dns_analysis() {
  local domain=""
  
  # Get domain
  read_input "Enter domain for DNS analysis: " domain validate_domain required
  
  # Create target directory
  local target_dir="$DOMAIN_DATA_DIR/$domain"
  sudo mkdir -p "$target_dir"
  
  section_header "DNS Analysis: $domain"
  
  # Ensure domain container is running
  echo -e "${YELLOW}Starting domain intelligence container...${NC}"
  sudo $CONTAINER_MANAGER start $DOMAIN_CONTAINER
  
  # Run DNS analysis
  echo -e "${YELLOW}Running DNS record analysis...${NC}"
  cmd="bash -c \"echo $domain | dnsx -a -aaaa -cname -mx -ns -soa -txt -json -o /opt/osint/data/domain/$domain/dns_records.json\""
  sudo $CONTAINER_MANAGER exec $DOMAIN_CONTAINER $cmd &
  show_spinner $! "Retrieving DNS records..."
  
  # Process results and display
  if sudo test -f "$target_dir/dns_records.json"; then
    echo
    status_message success "DNS analysis completed"
    echo
    
    echo -e "${BLUE}DNS Records for $domain:${NC}"
    echo
    
    # Use jq if available for better JSON parsing
    if command -v jq >/dev/null 2>&1; then
      # A Records
      echo -e "${YELLOW}A Records:${NC}"
      sudo cat "$target_dir/dns_records.json" | jq -r '.host as $host | .a[]? | "\($host) -> " + .' 2>/dev/null || echo "None found"
      echo
      
      # AAAA Records
      echo -e "${YELLOW}AAAA Records:${NC}"
      sudo cat "$target_dir/dns_records.json" | jq -r '.host as $host | .aaaa[]? | "\($host) -> " + .' 2>/dev/null || echo "None found"
      echo
      
      # CNAME Records
      echo -e "${YELLOW}CNAME Records:${NC}"
      sudo cat "$target_dir/dns_records.json" | jq -r '.host as $host | .cname[]? | "\($host) -> " + .' 2>/dev/null || echo "None found"
      echo
      
      # MX Records
      echo -e "${YELLOW}MX Records:${NC}"
      sudo cat "$target_dir/dns_records.json" | jq -r '.host as $host | .mx[]? | "\($host) -> " + .' 2>/dev/null || echo "None found"
      echo
      
      # NS Records
      echo -e "${YELLOW}NS Records:${NC}"
      sudo cat "$target_dir/dns_records.json" | jq -r '.host as $host | .ns[]? | "\($host) -> " + .' 2>/dev/null || echo "None found"
      echo
      
      # TXT Records
      echo -e "${YELLOW}TXT Records:${NC}"
      sudo cat "$target_dir/dns_records.json" | jq -r '.host as $host | .txt[]? | "\($host) -> " + .' 2>/dev/null || echo "None found"
      echo
    else
      # Fallback to grep/sed if jq is not available
      # A Records
      echo -e "${YELLOW}A Records:${NC}"
      sudo grep -o '"a":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"a":\[\|"\|\]//g' | sed 's/,/\n/g' || echo "None found"
      echo
      
      # AAAA Records
      echo -e "${YELLOW}AAAA Records:${NC}"
      sudo grep -o '"aaaa":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"aaaa":\[\|"\|\]//g' | sed 's/,/\n/g' || echo "None found"
      echo
      
      # CNAME Records
      echo -e "${YELLOW}CNAME Records:${NC}"
      sudo grep -o '"cname":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"cname":\[\|"\|\]//g' | sed 's/,/\n/g' || echo "None found"
      echo
      
      # MX Records
      echo -e "${YELLOW}MX Records:${NC}"
      sudo grep -o '"mx":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"mx":\[\|"\|\]//g' | sed 's/,/\n/g' || echo "None found"
      echo
      
      # NS Records
      echo -e "${YELLOW}NS Records:${NC}"
      sudo grep -o '"ns":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"ns":\[\|"\|\]//g' | sed 's/,/\n/g' || echo "None found"
      echo
      
      # TXT Records
      echo -e "${YELLOW}TXT Records:${NC}"
      sudo grep -o '"txt":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"txt":\[\|"\|\]//g' | sed 's/,/\n/g' || echo "None found"
      echo
    fi
  else
    status_message error "DNS analysis failed or no records found"
  fi
  
  read -p "Press Enter to continue..." dummy
}

# Export domain data
export_domain_data() {
  # Check if any domains have been scanned
  if ! sudo test -d "$DOMAIN_DATA_DIR" || [ -z "$(sudo ls -A "$DOMAIN_DATA_DIR" 2>/dev/null)" ]; then
    status_message error "No domain data available for export"
    sleep 2
    return
  fi
  
  # List available domains
  section_header "Export Domain Data"
  echo -e "${BLUE}Available domains:${NC}"
  echo
  
  # Get list of domains
  local domains=$(sudo ls -1 "$DOMAIN_DATA_DIR")
  local domain_count=$(echo "$domains" | wc -l)
  local domain_array=($domains)
  
  # Display domains with numbers
  for i in "${!domain_array[@]}"; do
    echo -e "$((i+1)). ${domain_array[$i]}"
  done
  echo
  
  # Select domain
  read_input "Select domain (1-$domain_count): " domain_idx validate_number
  
  if [[ "$domain_idx" -ge 1 && "$domain_idx" -le "$domain_count" ]]; then
    local selected_domain="${domain_array[$((domain_idx-1))]}"
    local domain_dir="$DOMAIN_DATA_DIR/$selected_domain"
    
    # Create export directory
    local export_dir="$DATA_DIR/exports"
    sudo mkdir -p "$export_dir"
    
    # Export filename with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="$export_dir/${selected_domain}_domain_${timestamp}.tar.gz"
    
    # Create archive
    echo -e "${YELLOW}Creating export archive...${NC}"
    sudo tar -czf "$export_file" -C "$DOMAIN_DATA_DIR" "$selected_domain"
    
    if [ $? -eq 0 ]; then
      status_message success "Domain data exported to $export_file"
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

# Domain intelligence menu
domain_menu() {
  show_header
  echo -e "${BLUE}[🌐] DOMAIN INTELLIGENCE${NC}"
  echo -e "1. Domain Reconnaissance"
  echo -e "2. Subdomain Enumeration"
  echo -e "3. DNS Analysis"
  echo -e "4. Export Domain Data"
  echo -e "9. Back to Main Menu"
  echo -e "0. Exit"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1) domain_recon ;;
    2) subdomain_enum ;;
    3) dns_analysis ;;
    4) export_domain_data ;;
    9) return 0 ;;
    0) exit 0 ;;
    *) 
      status_message error "Invalid option"
      sleep 1
      ;;
  esac
  
  # Return to domain menu after function completes
  domain_menu
  return 0
}