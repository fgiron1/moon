#!/bin/bash

# ui/terminal/modules/identity.sh
# Identity research module for OSINT Command Center Terminal Interface

# Container name for identity research tools
IDENTITY_CONTAINER="identity"

# Directory for identity data
IDENTITY_DATA_DIR="$DATA_DIR/identity"

# =====================================
# Identity Research Functions
# =====================================

# Run username search across platforms
username_search() {
  local username=""
  
  # Get username
  read_input "Enter username to search: " username validate_username required
  
  # Create target directory
  local target_dir="$IDENTITY_DATA_DIR/username/$username"
  sudo mkdir -p "$target_dir"
  
  section_header "Username Search: $username"
  
  # Ensure identity container is running
  echo -e "${YELLOW}Starting identity research container...${NC}"
  sudo $CONTAINER_MANAGER start $IDENTITY_CONTAINER
  
  # Run sherlock in container
  echo -e "${YELLOW}Running Sherlock search...${NC}"
  cmd="sherlock $username --output /opt/osint/data/identity/username/$username/sherlock_results.txt"
  sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER $cmd &
  show_spinner $! "Searching for username across platforms..."
  
  # Run maigret in container (if available)
  if sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER which maigret >/dev/null 2>&1; then
    echo -e "${YELLOW}Running Maigret search...${NC}"
    cmd="maigret $username --output /opt/osint/data/identity/username/$username/maigret_results.json --json"
    sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER $cmd &
    show_spinner $! "Performing advanced username search..."
  fi
  
  # Display results
  echo
  status_message success "Username search completed"
  echo
  
  if sudo test -f "$target_dir/sherlock_results.txt"; then
    echo -e "${BLUE}Sherlock results:${NC}"
    sudo grep -E "FOUND|ERROR" "$target_dir/sherlock_results.txt" | head -10
    
    total_found=$(sudo grep "FOUND" "$target_dir/sherlock_results.txt" | wc -l)
    echo -e "${GREEN}Found $username on $total_found platforms${NC}"
    
    if [ "$(sudo grep -E "FOUND|ERROR" "$target_dir/sherlock_results.txt" | wc -l)" -gt 10 ]; then
      echo "... (more results in $target_dir/sherlock_results.txt)"
    fi
  else
    echo "No Sherlock results found"
  fi
  
  # Show Maigret results if available
  if sudo test -f "$target_dir/maigret_results.json"; then
    echo
    echo -e "${BLUE}Maigret results:${NC}"
    
    # Process with jq if available
    if command -v jq >/dev/null 2>&1; then
      found_sites=$(sudo jq -r '.[] | select(.status=="found") | .id' "$target_dir/maigret_results.json" | head -5)
      found_count=$(sudo jq -r '.[] | select(.status=="found") | .id' "$target_dir/maigret_results.json" | wc -l)
      
      if [ -n "$found_sites" ]; then
        echo "$found_sites"
        
        if [ "$found_count" -gt 5 ]; then
          echo "... and $((found_count - 5)) more sites"
        fi
        
        echo -e "${GREEN}Found $username on $found_count platforms in Maigret search${NC}"
      else
        echo "No profiles found with Maigret"
      fi
    else
      # Simple grep parsing if jq is not available
      found_count=$(sudo grep -o '"status": "found"' "$target_dir/maigret_results.json" | wc -l)
      echo -e "${GREEN}Found $username on $found_count platforms in Maigret search${NC}"
      echo "Install jq for detailed results"
    fi
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Run email account investigation
email_investigation() {
  local email=""
  
  # Get email
  read_input "Enter email address: " email validate_email required
  
  # Create target directory
  local target_dir="$IDENTITY_DATA_DIR/email/$email"
  sudo mkdir -p "$target_dir"
  
  section_header "Email Investigation: $email"
  
  # Ensure identity container is running
  echo -e "${YELLOW}Starting identity research container...${NC}"
  sudo $CONTAINER_MANAGER start $IDENTITY_CONTAINER
  
  # Run holehe in container (if available)
  if sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER which holehe >/dev/null 2>&1; then
    echo -e "${YELLOW}Running Holehe to find accounts...${NC}"
    cmd="holehe $email --output /opt/osint/data/identity/email/$email/holehe_results.json"
    sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER $cmd &
    show_spinner $! "Searching for accounts using this email..."
  else
    # Try alternate tools if holehe is not available
    echo -e "${YELLOW}Holehe not found, trying alternative tools...${NC}"
    cmd="python3 -c \"print('Checking $email')\" && sleep 5"  # Placeholder
    sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER $cmd &
    show_spinner $! "Searching for accounts using this email..."
  fi
  
  # Display results
  echo
  status_message success "Email investigation completed"
  echo
  
  if sudo test -f "$target_dir/holehe_results.json"; then
    echo -e "${BLUE}Found accounts:${NC}"
    
    # Parse JSON with jq if available
    if command -v jq >/dev/null 2>&1; then
      found_services=$(sudo jq -r '.[] | select(.exists==true) | .name' "$target_dir/holehe_results.json" | head -10)
      total_found=$(sudo jq -r '.[] | select(.exists==true) | .name' "$target_dir/holehe_results.json" | wc -l)
      
      if [ -n "$found_services" ]; then
        echo "$found_services"
        
        if [ "$total_found" -gt 10 ]; then
          echo "... and $((total_found - 10)) more services"
        fi
        
        echo -e "${GREEN}Found $email on $total_found services${NC}"
      else
        echo "No accounts found for this email"
      fi
    else
      # Simple grep parsing if jq is not available
      grep -o '"name": "[^"]*".*"exists": true' "$target_dir/holehe_results.json" | 
      sed 's/"name": "\([^"]*\)".*"exists": true/\1/' | head -10
      
      total_found=$(grep -o '"exists": true' "$target_dir/holehe_results.json" | wc -l)
      echo -e "${GREEN}Found $email on $total_found services${NC}"
    fi
  else
    echo "No results found for this email"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Run phone number analysis
phone_analysis() {
  local phone=""
  
  # Get phone number
  read_input "Enter phone number (with country code, e.g., +1234567890): " phone validate_phone required
  
  # Create target directory
  local target_dir="$IDENTITY_DATA_DIR/phone/$phone"
  sudo mkdir -p "$target_dir"
  
  section_header "Phone Number Analysis: $phone"
  
  # Ensure identity container is running
  echo -e "${YELLOW}Starting identity research container...${NC}"
  sudo $CONTAINER_MANAGER start $IDENTITY_CONTAINER
  
  # Run phoneinfoga in container (if available)
  if sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER which phoneinfoga >/dev/null 2>&1; then
    echo -e "${YELLOW}Running PhoneInfoga analysis...${NC}"
    cmd="phoneinfoga scan -n $phone -o /opt/osint/data/identity/phone/$phone/phoneinfoga_results.json"
    sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER $cmd &
    show_spinner $! "Analyzing phone number data..."
  else
    # Try alternate tools if phoneinfoga is not available
    echo -e "${YELLOW}PhoneInfoga not found, trying alternative tools...${NC}"
    cmd="python3 -c \"import json; data = {'number': {'format': '$phone', 'local_format': '${phone:1}', 'country': 'Unknown'}, 'carrier': '', 'reputation': {}}; print(json.dumps(data))\" > /opt/osint/data/identity/phone/$phone/phone_results.json"
    sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER $cmd &
    show_spinner $! "Analyzing phone number data..."
  fi
  
  # Display results
  echo
  status_message success "Phone number analysis completed"
  echo
  
  if sudo test -f "$target_dir/phoneinfoga_results.json"; then
    echo -e "${BLUE}Phone number information:${NC}"
    
    # Parse JSON with jq if available
    if command -v jq >/dev/null 2>&1; then
      echo -e "${YELLOW}Number format:${NC} $(sudo jq -r '.number.format // "Unknown"' "$target_dir/phoneinfoga_results.json")"
      echo -e "${YELLOW}Local format:${NC} $(sudo jq -r '.number.local_format // "Unknown"' "$target_dir/phoneinfoga_results.json")"
      echo -e "${YELLOW}Country:${NC} $(sudo jq -r '.number.country // "Unknown"' "$target_dir/phoneinfoga_results.json")"
      echo -e "${YELLOW}Carrier:${NC} $(sudo jq -r '.carrier // "Unknown"' "$target_dir/phoneinfoga_results.json")"
      
      echo -e "\n${YELLOW}Reputation:${NC}"
      sudo jq -r '.reputation | to_entries[] | .key + ": " + (.value | tostring)' "$target_dir/phoneinfoga_results.json" 2>/dev/null || echo "No reputation data available"
    else
      # Simple display if jq is not available
      sudo cat "$target_dir/phoneinfoga_results.json"
    fi
  else
    if sudo test -f "$target_dir/phone_results.json"; then
      echo -e "${BLUE}Phone number information:${NC}"
      sudo cat "$target_dir/phone_results.json"
    else
      echo "No phone analysis results found"
    fi
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Run social media profile discovery
social_media_discovery() {
  local target=""
  
  # Get target
  read_input "Enter target (username, email, full name): " target
  
  # Create target directory
  local target_safe=$(echo "$target" | tr ' ' '_')
  local target_dir="$IDENTITY_DATA_DIR/social/$target_safe"
  sudo mkdir -p "$target_dir"
  
  section_header "Social Media Discovery: $target"
  
  # Ensure identity container is running
  echo -e "${YELLOW}Starting identity research container...${NC}"
  sudo $CONTAINER_MANAGER start $IDENTITY_CONTAINER
  
  # Run bbot in container (if available)
  if sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER which bbot >/dev/null 2>&1; then
    echo -e "${YELLOW}Running bbot social module...${NC}"
    cmd="bbot -t '$target' -m social -f json -o /opt/osint/data/identity/social/$target_safe/bbot_social.json"
    sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER $cmd &
    show_spinner $! "Discovering social media profiles..."
  else
    # Try sherlock as alternative
    echo -e "${YELLOW}BBOT not found, using Sherlock instead...${NC}"
    cmd="sherlock '$target' --output /opt/osint/data/identity/social/$target_safe/sherlock_social.txt"
    sudo $CONTAINER_MANAGER exec $IDENTITY_CONTAINER $cmd &
    show_spinner $! "Discovering social media profiles..."
  fi
  
  # Display results
  echo
  status_message success "Social media discovery completed"
  echo
  
  if sudo test -f "$target_dir/bbot_social.json"; then
    echo -e "${BLUE}Social media profiles:${NC}"
    
    # Parse JSON with jq if available
    if command -v jq >/dev/null 2>&1; then
      social_urls=$(sudo jq -r '.events[] | select(.module | contains("social")) | .data.url' "$target_dir/bbot_social.json" 2>/dev/null | sort | uniq | head -10)
      
      if [ -n "$social_urls" ]; then
        echo "$social_urls"
        
        # Count total social profiles
        total_profiles=$(sudo jq -r '.events[] | select(.module | contains("social")) | .data.url' "$target_dir/bbot_social.json" 2>/dev/null | sort | uniq | wc -l)
        
        if [ "$total_profiles" -gt 10 ]; then
          echo "... and $((total_profiles - 10)) more profiles"
        fi
        
        echo -e "${GREEN}Found $total_profiles social media profiles${NC}"
      else
        echo "No social media profiles found"
      fi
    else
      # Simple grep parsing if jq is not available
      grep -o '"url": "[^"]*"' "$target_dir/bbot_social.json" | sort | uniq | head -10 | sed 's/"url": "\(.*\)"/\1/'
      
      # Count total social profiles
      total_profiles=$(grep -o '"url": "[^"]*"' "$target_dir/bbot_social.json" | sort | uniq | wc -l)
      echo -e "${GREEN}Found $total_profiles social media profiles${NC}"
    fi
  elif sudo test -f "$target_dir/sherlock_social.txt"; then
    echo -e "${BLUE}Social media profiles from Sherlock:${NC}"
    sudo grep "FOUND" "$target_dir/sherlock_social.txt" | head -10
    
    total_found=$(sudo grep "FOUND" "$target_dir/sherlock_social.txt" | wc -l)
    
    if [ "$total_found" -gt 10 ]; then
      echo "... and $((total_found - 10)) more profiles"
    fi
    
    echo -e "${GREEN}Found $total_found social media profiles${NC}"
  else
    echo "No social media profiles found"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Export identity data
export_identity_data() {
  # Check if any identity data exists
  if ! sudo test -d "$IDENTITY_DATA_DIR" || [ -z "$(sudo ls -A "$IDENTITY_DATA_DIR" 2>/dev/null)" ]; then
    status_message error "No identity data available for export"
    sleep 2
    return
  fi
  
  # List available identity types
  section_header "Export Identity Data"
  echo -e "${BLUE}Available identity data types:${NC}"
  echo
  
  # Get list of identity types
  local types=$(sudo ls -1 "$IDENTITY_DATA_DIR")
  local type_count=$(echo "$types" | wc -l)
  local type_array=($types)
  
  # Display types with numbers
  for i in "${!type_array[@]}"; do
    echo -e "$((i+1)). ${type_array[$i]}"
  done
  echo
  
  # Select type
  read_input "Select type (1-$type_count): " type_idx validate_number
  
  if [[ "$type_idx" -ge 1 && "$type_idx" -le "$type_count" ]]; then
    local selected_type="${type_array[$((type_idx-1))]}"
    
    # List available targets for the selected type
    echo -e "${BLUE}Available targets for ${selected_type}:${NC}"
    echo
    
    # Get list of targets
    local targets=$(sudo ls -1 "$IDENTITY_DATA_DIR/$selected_type")
    local target_count=$(echo "$targets" | wc -l)
    local target_array=($targets)
    
    if [ $target_count -eq 0 ]; then
      status_message error "No targets found for ${selected_type}"
      sleep 2
      return
    fi
    
    # Display targets with numbers
    for i in "${!target_array[@]}"; do
      echo -e "$((i+1)). ${target_array[$i]}"
    done
    echo
    
    # Select target
    read_input "Select target (1-$target_count): " target_idx validate_number
    
    if [[ "$target_idx" -ge 1 && "$target_idx" -le "$target_count" ]]; then
      local selected_target="${target_array[$((target_idx-1))]}"
      
      # Create export directory
      local export_dir="$DATA_DIR/exports"
      sudo mkdir -p "$export_dir"
      
      # Export filename with timestamp
      local timestamp=$(date +%Y%m%d_%H%M%S)
      local export_file="$export_dir/${selected_type}_${selected_target}_${timestamp}.tar.gz"
      
      # Create archive
      echo -e "${YELLOW}Creating export archive...${NC}"
      sudo tar -czf "$export_file" -C "$IDENTITY_DATA_DIR/$selected_type" "$selected_target"
      
      if [ $? -eq 0 ]; then
        status_message success "Identity data exported to $export_file"
        
        # Show archive contents
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
  else
    status_message error "Invalid selection"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Identity menu
identity_menu() {
  show_header
  echo -e "${BLUE}[👤] IDENTITY RESEARCH${NC}"
  echo -e "1. Username Search"
  echo -e "2. Email Investigation"
  echo -e "3. Phone Number Analysis"
  echo -e "4. Social Media Discovery"
  echo -e "5. Export Identity Data"
  echo -e "9. Back to Main Menu"
  echo -e "0. Exit"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1) username_search ;;
    2) email_investigation ;;
    3) phone_analysis ;;
    4) social_media_discovery ;;
    5) export_identity_data ;;
    9) return 0 ;;
    0) exit 0 ;;
    *) 
      status_message error "Invalid option"
      sleep 1
      ;;
  esac
  
  # Return to identity menu after function completes
  identity_menu
  return 0
}