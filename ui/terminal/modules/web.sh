#!/bin/bash

# ui/terminal/modules/web.sh
# Web analysis module for OSINT Command Center Terminal Interface

# Load helper functions
source "$SCRIPT_DIR/helpers/helpers.sh"

# Define directories
WEB_DATA_DIR="${DATA_DIR}/web"

# Container name for web analysis tools
WEB_CONTAINER="web"

# =====================================
# Web Analysis Functions
# =====================================

# Run website security scan
website_scan() {
  local url=""
  
  # Get URL
  read_input "Enter website URL: " url validate_url required
  
  # Create target directory
  local target_safe=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
  local target_dir="$WEB_DATA_DIR/$target_safe"
  sudo mkdir -p "$target_dir"
  
  section_header "Website Scan: $url"
  
  # Ensure web container is running
  echo -e "${YELLOW}Starting web analysis container...${NC}"
  sudo $CONTAINER_MANAGER start $WEB_CONTAINER
  
  # Run httpx in container to verify URL is accessible
  echo -e "${YELLOW}Verifying URL accessibility...${NC}"
  cmd="httpx -u $url -json -o $WEB_DATA_DIR/$target_safe/httpx_results.json"
  sudo $CONTAINER_MANAGER exec $WEB_CONTAINER $cmd &
  show_spinner $! "Checking website availability..."
  
  # Check if website is accessible
  if ! sudo test -f "$target_dir/httpx_results.json"; then
    status_message error "Website is not accessible"
    read -p "Press Enter to continue..." dummy
    return
  fi
  
  # Run nuclei in container for vulnerability scanning (if available)
  if sudo $CONTAINER_MANAGER exec $WEB_CONTAINER which nuclei >/dev/null 2>&1; then
    echo -e "${YELLOW}Running vulnerability scan...${NC}"
    cmd="nuclei -u $url -severity low,medium,high,critical -json -o $WEB_DATA_DIR/$target_safe/nuclei_results.json"
    sudo $CONTAINER_MANAGER exec $WEB_CONTAINER $cmd &
    show_spinner $! "Scanning for vulnerabilities..."
  fi
  
  # Run hakrawler in container for crawling (if available)
  if sudo $CONTAINER_MANAGER exec $WEB_CONTAINER which hakrawler >/dev/null 2>&1; then
    echo -e "${YELLOW}Crawling website...${NC}"
    cmd="bash -c 'echo $url | hakrawler -depth 2 -js -plain > $WEB_DATA_DIR/$target_safe/hakrawler_results.txt'"
    sudo $CONTAINER_MANAGER exec $WEB_CONTAINER $cmd &
    show_spinner $! "Crawling and discovering website assets..."
  fi
  
  # Display results
  echo
  status_message success "Website scan completed"
  echo
  
  # Display vulnerabilities if found
  if sudo test -f "$target_dir/nuclei_results.json"; then
    echo -e "${BLUE}Vulnerabilities found:${NC}"
    
    # Parse JSON with jq if available
    if command -v jq >/dev/null 2>&1; then
      vulns=$(sudo jq -r '.info.severity + ": " + .info.name' "$target_dir/nuclei_results.json" 2>/dev/null | sort | uniq | head -10)
      
      if [ -n "$vulns" ]; then
        echo "$vulns"
        
        vuln_count=$(sudo jq -r '.info.name' "$target_dir/nuclei_results.json" 2>/dev/null | wc -l)
        
        if [ "$vuln_count" -gt 10 ]; then
          echo "... and $((vuln_count - 10)) more vulnerabilities"
        fi
        
        echo -e "${GREEN}Found $vuln_count potential vulnerabilities${NC}"
      else
        echo "No vulnerabilities detected"
      fi
    else
      # Simple grep parsing if jq is not available
      sudo grep -o '"name": "[^"]*".*"severity": "[^"]*"' "$target_dir/nuclei_results.json" | head -10
      
      vuln_count=$(sudo grep -o '"name": "[^"]*"' "$target_dir/nuclei_results.json" | wc -l)
      echo -e "${GREEN}Found $vuln_count potential vulnerabilities${NC}"
    fi
  else
    echo -e "${YELLOW}No vulnerabilities found or nuclei not available${NC}"
  fi
  
  echo
  
  # Display crawled URLs
  if sudo test -f "$target_dir/hakrawler_results.txt"; then
    echo -e "${BLUE}Discovered URLs:${NC}"
    sudo head -10 "$target_dir/hakrawler_results.txt"
    
    url_count=$(sudo wc -l < "$target_dir/hakrawler_results.txt")
    
    if [ "$url_count" -gt 10 ]; then
      echo "... and $((url_count - 10)) more URLs"
    fi
    
    echo -e "${GREEN}Found $url_count URLs${NC}"
  else
    echo -e "${YELLOW}No URLs discovered or hakrawler not available${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Run technology detection
tech_detection() {
  local url=""
  
  # Get URL
  read_input "Enter website URL: " url validate_url required
  
  # Create target directory
  local target_safe=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
  local target_dir="$WEB_DATA_DIR/$target_safe"
  sudo mkdir -p "$target_dir"
  
  section_header "Technology Detection: $url"
  
  # Ensure web container is running
  echo -e "${YELLOW}Starting web analysis container...${NC}"
  sudo $CONTAINER_MANAGER start $WEB_CONTAINER
  
  # Run whatweb in container (if available)
  if sudo $CONTAINER_MANAGER exec $WEB_CONTAINER which whatweb >/dev/null 2>&1; then
    echo -e "${YELLOW}Detecting website technologies with WhatWeb...${NC}"
    cmd="whatweb -a 3 --log-json=$WEB_DATA_DIR/$target_safe/whatweb_results.json $url"
    sudo $CONTAINER_MANAGER exec $WEB_CONTAINER $cmd &
    show_spinner $! "Analyzing website technologies..."
  fi
  
  # Run httpx with tech detection (if available)
  if sudo $CONTAINER_MANAGER exec $WEB_CONTAINER which httpx >/dev/null 2>&1; then
    echo -e "${YELLOW}Running additional technology detection with httpx...${NC}"
    cmd="httpx -u $url -json -o $WEB_DATA_DIR/$target_safe/httpx_tech_results.json -tech-detect"
    sudo $CONTAINER_MANAGER exec $WEB_CONTAINER $cmd &
    show_spinner $! "Identifying technologies and frameworks..."
  fi
  
  # Display results
  echo
  status_message success "Technology detection completed"
  echo
  
  # Display technologies if found (whatweb)
  if sudo test -f "$target_dir/whatweb_results.json"; then
    echo -e "${BLUE}Technologies detected:${NC}"
    
    # Parse JSON with jq if available
    if command -v jq >/dev/null 2>&1; then
      # Extract general metadata
      meta=$(sudo jq -r '.[0] | to_entries[] | select(.key != "target" and .key != "http_status" and .key != "plugins") | .key + ": " + (.value | tostring)' "$target_dir/whatweb_results.json" 2>/dev/null)
      
      if [ -n "$meta" ]; then
        echo "$meta"
      fi
      
      echo -e "\n${BLUE}Software/Frameworks:${NC}"
      software=$(sudo jq -r '.[0].plugins | to_entries[] | .key' "$target_dir/whatweb_results.json" 2>/dev/null | head -15)
      
      if [ -n "$software" ]; then
        echo "$software"
        
        # Count total technologies
        tech_count=$(sudo jq -r '.[0].plugins | keys | length' "$target_dir/whatweb_results.json" 2>/dev/null)
        
        if [ "$tech_count" -gt 15 ]; then
          echo "... and $((tech_count - 15)) more technologies"
        fi
      else
        echo "No technologies detected"
      fi
    else
      # Simple grep parsing if jq is not available
      sudo grep -o '"[^"]*": \[{"version"' "$target_dir/whatweb_results.json" | cut -d'"' -f2 | head -15
    fi
  else
    echo -e "${YELLOW}No technology data from WhatWeb${NC}"
  fi
  
  echo
  
  # Display httpx technologies if found
  if sudo test -f "$target_dir/httpx_tech_results.json"; then
    echo -e "${BLUE}Additional technologies:${NC}"
    
    # Parse JSON with jq if available
    if command -v jq >/dev/null 2>&1; then
      techs=$(sudo jq -r '.technologies[]' "$target_dir/httpx_tech_results.json" 2>/dev/null | sort | uniq)
      
      if [ -n "$techs" ]; then
        echo "$techs"
      else
        echo "No additional technologies detected"
      fi
    else
      # Simple grep parsing if jq is not available
      sudo grep -o '"technologies":\[[^]]*\]' "$target_dir/httpx_tech_results.json" | 
      sed 's/"technologies":\[//g' | sed 's/\]//g' | sed 's/"//g' | tr ',' '\n'
    fi
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Run content discovery
content_discovery() {
  local url=""
  
  # Get URL
  read_input "Enter website URL: " url validate_url required
  
  # Create target directory
  local target_safe=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
  local target_dir="$WEB_DATA_DIR/$target_safe"
  sudo mkdir -p "$target_dir"
  
  section_header "Content Discovery: $url"
  
  # Ensure web container is running
  echo -e "${YELLOW}Starting web analysis container...${NC}"
  sudo $CONTAINER_MANAGER start $WEB_CONTAINER
  
  # Run feroxbuster in container (if available)
  if sudo $CONTAINER_MANAGER exec $WEB_CONTAINER which feroxbuster >/dev/null 2>&1; then
    echo -e "${YELLOW}Running directory brute force with feroxbuster...${NC}"
    cmd="feroxbuster --url $url --depth 2 --silent -o $WEB_DATA_DIR/$target_safe/ferox_results.txt"
    sudo $CONTAINER_MANAGER exec $WEB_CONTAINER $cmd &
    show_spinner $! "Discovering hidden directories and files..."
  fi
  
  # Run hakrawler in container for JS file discovery (if available)
  if sudo $CONTAINER_MANAGER exec $WEB_CONTAINER which hakrawler >/dev/null 2>&1; then
    echo -e "${YELLOW}Discovering JavaScript files...${NC}"
    cmd="bash -c 'echo $url | hakrawler -depth 2 -js > $WEB_DATA_DIR/$target_safe/js_files.txt'"
    sudo $CONTAINER_MANAGER exec $WEB_CONTAINER $cmd &
    show_spinner $! "Finding JavaScript files..."
  fi
  
  # Display results
  echo
  status_message success "Content discovery completed"
  echo
  
  # Display discovered directories and files (feroxbuster)
  if sudo test -f "$target_dir/ferox_results.txt"; then
    echo -e "${BLUE}Discovered directories and files:${NC}"
    # Filter out empty lines and show only the interesting findings
    sudo grep -E "200|301|302" "$target_dir/ferox_results.txt" | head -15
    
    # Count the findings
    total_found=$(sudo grep -E "200|301|302" "$target_dir/ferox_results.txt" | wc -l)
    
    if [ "$total_found" -gt 15 ]; then
      echo "... and $((total_found - 15)) more resources"
    fi
    
    echo -e "${GREEN}Found $total_found resources${NC}"
  else
    echo -e "${YELLOW}No directories or files discovered${NC}"
  fi
  
  echo
  
  # Display discovered JS files (hakrawler)
  if sudo test -f "$target_dir/js_files.txt"; then
    echo -e "${BLUE}JavaScript files:${NC}"
    
    # Filter for JS files only and display
    js_files=$(sudo grep "\.js" "$target_dir/js_files.txt" | head -10)
    
    if [ -n "$js_files" ]; then
      echo "$js_files"
      
      # Count the JS files
      js_count=$(sudo grep "\.js" "$target_dir/js_files.txt" | wc -l)
      
      if [ "$js_count" -gt 10 ]; then
        echo "... and $((js_count - 10)) more JavaScript files"
      fi
      
      echo -e "${GREEN}Found $js_count JavaScript files${NC}"
    else
      echo "No JavaScript files discovered"
    fi
  else
    echo -e "${YELLOW}No JavaScript files discovered${NC}"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Export web analysis data
export_web_data() {
  # Check if any web data exists
  if ! sudo test -d "$WEB_DATA_DIR" || [ -z "$(sudo ls -A "$WEB_DATA_DIR" 2>/dev/null)" ]; then
    status_message error "No web analysis data available for export"
    sleep 2
    return
  fi
  
  # List available websites
  section_header "Export Web Analysis Data"
  echo -e "${BLUE}Available websites:${NC}"
  echo
  
  # Get list of websites
  local websites=$(sudo ls -1 "$WEB_DATA_DIR")
  local website_count=$(echo "$websites" | wc -l)
  local website_array=($websites)
  
  # Display websites with numbers
  for i in "${!website_array[@]}"; do
    echo -e "$((i+1)). ${website_array[$i]}"
  done
  echo
  
  # Select website
  read_input "Select website (1-$website_count): " website_idx validate_number
  
  if [[ "$website_idx" -ge 1 && "$website_idx" -le "$website_count" ]]; then
    local selected_website="${website_array[$((website_idx-1))]}"
    
    # Create export directory
    local export_dir="$DATA_DIR/exports"
    sudo mkdir -p "$export_dir"
    
    # Export filename with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="$export_dir/web_${selected_website}_${timestamp}.tar.gz"
    
    # Create archive
    echo -e "${YELLOW}Creating export archive...${NC}"
    sudo tar -czf "$export_file" -C "$WEB_DATA_DIR" "$selected_website"
    
    if [ $? -eq 0 ]; then
      status_message success "Web analysis data exported to $export_file"
      
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
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Web analysis menu
web_menu() {
  show_header
  echo -e "${BLUE}[🕸️] WEB ANALYSIS${NC}"
  echo -e "1. Website Security Scan"
  echo -e "2. Technology Detection"
  echo -e "3. Content Discovery"
  echo -e "4. Export Web Analysis Data"
  echo -e "9. Back to Main Menu"
  echo -e "0. Exit"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1) website_scan ;;
    2) tech_detection ;;
    3) content_discovery ;;
    4) export_web_data ;;
    9) return 0 ;;
    0) exit 0 ;;
    *) 
      status_message error "Invalid option"
      sleep 1
      ;;
  esac
  
  # Return to web menu after function completes
  web_menu
  return 0
}