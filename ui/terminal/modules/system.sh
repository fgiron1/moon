#!/bin/bash

# ui/terminal/modules/system.sh
# System control module for OSINT Command Center Terminal Interface

# =====================================
# System Tools Update Functions
# =====================================

# Update OSINT tools
update_tools() {
  section_header "Update OSINT Tools"
  
  echo -e "${YELLOW}Updating all OSINT tools...${NC}"
  sudo $SYSTEM_MANAGER update
  
  status_message success "OSINT tools updated successfully"
  echo
  read -p "Press Enter to continue..." dummy
}

# =====================================
# System Status Functions
# =====================================

# Check system status
check_system_status() {
  section_header "System Status"
  
  # Check container status
  echo -e "${BLUE}Container Status:${NC}"
  sudo $CONTAINER_MANAGER list
  echo
  
  # Check system metrics
  echo -e "${BLUE}System Metrics:${NC}"
  echo -e "${YELLOW}CPU Usage:${NC} $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
  echo -e "${YELLOW}Memory Usage:${NC} $(free -h | grep Mem | awk '{print $3 " used of " $2}')"
  echo -e "${YELLOW}Disk Usage:${NC} $(df -h / | grep / | awk '{print $3 " used of " $2 " (" $5 ")"}')"
  echo
  
  # Check network interfaces
  echo -e "${BLUE}Network Interfaces:${NC}"
  ip -o addr show | grep -v "lo" | awk '{print $2 ": " $4}' | cut -d/ -f1
  echo
  
  # Check VPN status
  echo -e "${BLUE}VPN Status:${NC}"
  if sudo vpn status | grep -q "VPN is active"; then
    echo -e "${GREEN}VPN is active${NC}"
  else
    echo -e "${RED}VPN is inactive${NC}"
  fi
  echo
  
  # Check external IP
  echo -e "${BLUE}External IP:${NC}"
  curl -s https://ipinfo.io/ip
  echo
  
  # Check Tor status
  if command -v tor-control >/dev/null 2>&1; then
    echo -e "${BLUE}Tor Status:${NC}"
    if systemctl is-active tor >/dev/null && sudo tor-control status | grep -q "connected through Tor"; then
      echo -e "${GREEN}Tor routing is active${NC}"
    else
      echo -e "${RED}Tor routing is not active${NC}"
    fi
    echo
  fi
  
  # Check system uptime
  echo -e "${BLUE}System Uptime:${NC}"
  uptime -p
  echo
  
  # Check last security audit
  if [ -d "$DATA_DIR/security_reports" ]; then
    echo -e "${BLUE}Last Security Audit:${NC}"
    ls -lt "$DATA_DIR/security_reports" | head -2 | tail -1 | awk '{print $6, $7, $8}'
  fi
  
  read -p "Press Enter to continue..." dummy
}

# =====================================
# Data Management Functions
# =====================================

# Manage data
manage_data() {
  section_header "Data Management"
  
  echo -e "1. List Data Directories"
  echo -e "2. Backup Data"
  echo -e "3. Secure Data Wipe"
  echo -e "4. View Disk Usage"
  echo -e "9. Back"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1)
      section_header "Data Directories"
      
      echo -e "${BLUE}Target Data:${NC}"
      sudo ls -lah "$DATA_DIR/targets/" 2>/dev/null || echo "No target data found"
      echo
      
      echo -e "${BLUE}Exported Data:${NC}"
      sudo ls -lah "$DATA_DIR/exports/" 2>/dev/null || echo "No exported data found"
      echo
      
      echo -e "${BLUE}Reports:${NC}"
      sudo ls -lah "$DATA_DIR/reports/" 2>/dev/null || echo "No reports found"
      echo
      
      read -p "Press Enter to continue..." dummy
      manage_data
      ;;
    2)
      section_header "Backup Data"
      
      # Generate backup timestamp
      local timestamp=$(date +%Y%m%d_%H%M%S)
      local backup_dir="$DATA_DIR/backups"
      local backup_file="$backup_dir/osint_backup_$timestamp.tar.gz"
      
      # Create backup directory if it doesn't exist
      sudo mkdir -p "$backup_dir"
      
      echo -e "${YELLOW}Creating backup...${NC}"
      sudo tar -czf "$backup_file" -C "$DATA_DIR" targets exports reports 2>/dev/null
      
      if [[ $? -eq 0 && -f "$backup_file" ]]; then
        status_message success "Backup created successfully: $backup_file"
        echo -e "${YELLOW}Backup size: $(sudo du -h "$backup_file" | cut -f1)${NC}"
      else
        status_message error "Backup creation failed"
      fi
      
      echo
      read -p "Press Enter to continue..." dummy
      manage_data
      ;;
    3)
      section_header "Secure Data Wipe"
      
      echo -e "${RED}WARNING: This will permanently delete data. This cannot be undone.${NC}"
      echo -e "1. Wipe specific target"
      echo -e "2. Wipe all exports"
      echo -e "3. Wipe all data (DANGEROUS)"
      echo -e "4. Back"
      echo
      
      read_input "Select option: " wipe_option validate_number
      
      case $wipe_option in
        1)
          # List targets
          echo -e "${BLUE}Available targets:${NC}"
          if [[ -d "$DATA_DIR/targets" && "$(sudo ls -A "$DATA_DIR/targets" 2>/dev/null)" ]]; then
            local targets=$(sudo ls -1 "$DATA_DIR/targets")
            local target_count=$(echo "$targets" | wc -l)
            local target_array=($targets)
            
            for i in "${!target_array[@]}"; do
              echo -e "$((i+1)). ${target_array[$i]}"
            done
            echo
            
            read_input "Select target to wipe (1-$target_count): " target_idx validate_number
            
            if [[ "$target_idx" -ge 1 && "$target_idx" -le "$target_count" ]]; then
              local selected_target="${target_array[$((target_idx-1))]}"
              
              echo -e "${RED}You are about to securely wipe target: $selected_target${NC}"
              read -p "Type the target name to confirm: " confirm
              
              if [[ "$confirm" == "$selected_target" ]]; then
                echo -e "${YELLOW}Wiping target data...${NC}"
                
                # Use secure-delete if available, otherwise use rm
                if sudo which srm >/dev/null 2>&1; then
                  sudo srm -r "$DATA_DIR/targets/$selected_target"
                else
                  sudo rm -rf "$DATA_DIR/targets/$selected_target"
                fi
                
                # Also remove from other directories if they exist
                for dir in standardized exports reports; do
                  if [ -d "$DATA_DIR/$dir/$selected_target" ]; then
                    if sudo which srm >/dev/null 2>&1; then
                      sudo srm -r "$DATA_DIR/$dir/$selected_target"
                    else
                      sudo rm -rf "$DATA_DIR/$dir/$selected_target"
                    fi
                  fi
                done
                
                status_message success "Target data wiped successfully"
              else
                status_message error "Confirmation failed, wipe aborted"
              fi
            else
              status_message error "Invalid selection"
            fi
          else
            echo -e "${YELLOW}No targets found${NC}"
          fi
          ;;
        2)
          echo -e "${RED}You are about to securely wipe all exports${NC}"
          read -p "Type 'CONFIRM' to proceed: " confirm
          
          if [[ "$confirm" == "CONFIRM" ]]; then
            echo -e "${YELLOW}Wiping all exports...${NC}"
            
            # Use secure-delete if available, otherwise use rm
            if sudo which srm >/dev/null 2>&1; then
              sudo srm -r "$DATA_DIR/exports/"*
            else
              sudo rm -rf "$DATA_DIR/exports/"*
            fi
            
            status_message success "All exports wiped successfully"
          else
            status_message error "Confirmation failed, wipe aborted"
          fi
          ;;
        3)
          echo -e "${RED}!!! DANGER: You are about to wipe ALL OSINT data !!!${NC}"
          echo -e "${RED}This is an irreversible operation${NC}"
          read -p "Type 'YES I UNDERSTAND' to proceed: " confirm
          
          if [[ "$confirm" == "YES I UNDERSTAND" ]]; then
            echo -e "${YELLOW}Wiping all OSINT data...${NC}"
            
            # Use secure-delete if available, otherwise use rm
            if sudo which srm >/dev/null 2>&1; then
              sudo srm -r "$DATA_DIR/targets/"* "$DATA_DIR/exports/"* "$DATA_DIR/reports/"* "$DATA_DIR/standardized/"* 2>/dev/null
            else
              sudo rm -rf "$DATA_DIR/targets/"* "$DATA_DIR/exports/"* "$DATA_DIR/reports/"* "$DATA_DIR/standardized/"* 2>/dev/null
            fi
            
            status_message success "All OSINT data wiped successfully"
          else
            status_message error "Confirmation failed, wipe aborted"
          fi
          ;;
        4)
          manage_data
          return
          ;;
        *)
          status_message error "Invalid option"
          ;;
      esac
      
      echo
      read -p "Press Enter to continue..." dummy
      manage_data
      ;;
    4)
      section_header "Disk Usage"
      
      echo -e "${BLUE}Overall OSINT data usage:${NC}"
      sudo du -h -d 1 "$DATA_DIR" | sort -hr
      echo
      
      echo -e "${BLUE}Detailed usage:${NC}"
      echo -e "${YELLOW}Targets:${NC} $(sudo du -sh "$DATA_DIR/targets" 2>/dev/null | cut -f1 || echo "N/A")"
      echo -e "${YELLOW}Exports:${NC} $(sudo du -sh "$DATA_DIR/exports" 2>/dev/null | cut -f1 || echo "N/A")"
      echo -e "${YELLOW}Reports:${NC} $(sudo du -sh "$DATA_DIR/reports" 2>/dev/null | cut -f1 || echo "N/A")"
      echo -e "${YELLOW}Backups:${NC} $(sudo du -sh "$DATA_DIR/backups" 2>/dev/null | cut -f1 || echo "N/A")"
      echo
      
      echo -e "${BLUE}System disk usage:${NC}"
      df -h /
      
      echo
      read -p "Press Enter to continue..." dummy
      manage_data
      ;;
    9)
      return
      ;;
    *)
      status_message error "Invalid option"
      sleep 1
      manage_data
      ;;
  esac
}

# =====================================
# Log Viewing Functions
# =====================================

# View system logs
view_logs() {
  section_header "System Logs"
  
  echo -e "1. Container Logs"
  echo -e "2. Security Logs"
  echo -e "3. System Logs"
  echo -e "4. Application Logs"
  echo -e "9. Back"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1)
      section_header "Container Logs"
      
      # List containers
      echo -e "${BLUE}Available containers:${NC}"
      local containers=$(sudo $CONTAINER_MANAGER list | grep "Running" | awk '{print $1}')
      local container_count=$(echo "$containers" | wc -l)
      local container_array=($containers)
      
      if [ ${#container_array[@]} -eq 0 ]; then
        echo -e "${YELLOW}No running containers found${NC}"
        sleep 2
        view_logs
        return
      fi
      
      for i in "${!container_array[@]}"; do
        echo -e "$((i+1)). ${container_array[$i]}"
      done
      echo
      
      read_input "Select container number (or 0 to go back): " container_idx validate_number
      
      if [[ "$container_idx" -gt 0 && "$container_idx" -le "${#container_array[@]}" ]]; then
        # Get container name by index
        local container_name="${container_array[$((container_idx-1))]}"
        
        if [[ -n "$container_name" ]]; then
          echo -e "${YELLOW}Showing logs for $container_name:${NC}"
          echo
          sudo $CONTAINER_MANAGER exec $container_name tail -100 /var/log/container.log 2>/dev/null || 
          sudo $CONTAINER_MANAGER logs --tail 100 "$container_name"
        else
          status_message error "Invalid container selection"
        fi
      fi
      ;;
    2)
      section_header "Security Logs"
      
      echo -e "${BLUE}Last 50 authentication attempts:${NC}"
      sudo grep "authentication failure\|Failed password" /var/log/auth.log | tail -50
      echo
      
      echo -e "${BLUE}Failed login attempts summary:${NC}"
      sudo grep "Failed password" /var/log/auth.log | grep -oE "from [0-9.]+" | sort | uniq -c | sort -nr | head -10
      ;;
    3)
      section_header "System Logs"
      
      echo -e "${BLUE}System messages:${NC}"
      sudo tail -50 /var/log/syslog
      ;;
    4)
      section_header "Application Logs"
      
      echo -e "${BLUE}OSINT tools logs:${NC}"
      local log_files=$(sudo find "$DATA_DIR/logs" -type f -name "*.log" 2>/dev/null)
      local log_count=$(echo "$log_files" | wc -l)
      local log_array=($log_files)
      
      if [ ${#log_array[@]} -eq 0 ]; then
        echo -e "${YELLOW}No log files found${NC}"
        sleep 2
        view_logs
        return
      fi
      
      for i in "${!log_array[@]}"; do
        echo -e "$((i+1)). $(basename "${log_array[$i]}")"
      done
      echo
      
      read_input "Select log file number (or 0 to go back): " log_idx validate_number
      
      if [[ "$log_idx" -gt 0 && "$log_idx" -le "${#log_array[@]}" ]]; then
        # Get log file by index
        local log_file="${log_array[$((log_idx-1))]}"
        
        if [[ -n "$log_file" && -f "$log_file" ]]; then
          echo -e "${YELLOW}Showing log file: $(basename "$log_file")${NC}"
          echo
          sudo tail -50 "$log_file"
        else
          status_message error "Invalid log file selection"
        fi
      fi
      ;;
    9)
      return
      ;;
    *)
      status_message error "Invalid option"
      sleep 1
      view_logs
      ;;
  esac
  
  echo
  read -p "Press Enter to continue..." dummy
  view_logs
}

# =====================================
# Power Management Functions
# =====================================

# Power management
power_management() {
  section_header "Power Management"
  
  echo -e "${RED}WARNING: These operations affect the server${NC}"
  echo -e "1. Restart server"
  echo -e "2. Shutdown server"
  echo -e "3. Restart container services"
  echo -e "9. Back"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1)
      echo -e "${RED}You are about to restart the server${NC}"
      read -p "Are you sure you want to proceed? (yes/no): " confirm
      
      if [[ "$confirm" == "yes" ]]; then
        echo -e "${YELLOW}Restarting server...${NC}"
        sudo reboot
      else
        status_message info "Server restart canceled"
      fi
      ;;
    2)
      echo -e "${RED}You are about to shutdown the server${NC}"
      read -p "Are you sure you want to proceed? (yes/no): " confirm
      
      if [[ "$confirm" == "yes" ]]; then
        echo -e "${YELLOW}Shutting down server...${NC}"
        sudo shutdown -h now
      else
        status_message info "Server shutdown canceled"
      fi
      ;;
    3)
      echo -e "${YELLOW}Restarting container services...${NC}"
      sudo $CONTAINER_MANAGER restart
      status_message success "Container services restarted"
      ;;
    9)
      return
      ;;
    *)
      status_message error "Invalid option"
      ;;
  esac
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Run security audit
run_security_audit() {
  section_header "Security Audit"
  
  echo -e "${YELLOW}Running security audit...${NC}"
  
  # Check if security audit script exists
  if [ -f "/opt/osint/scripts/security_audit.sh" ]; then
    sudo /opt/osint/scripts/security_audit.sh &
    show_spinner $! "Running comprehensive security audit..."
    
    # Check if audit completed successfully
    if [ -d "$DATA_DIR/security_reports" ]; then
      status_message success "Security audit completed"
      
      # Show the most recent report
      local latest_report=$(sudo find "$DATA_DIR/security_reports" -type f -name "lynis_audit_*" | sort -r | head -1)
      
      if [ -n "$latest_report" ]; then
        echo -e "${BLUE}Latest Audit Results:${NC}"
        echo
        sudo head -20 "$latest_report"
        echo
        echo -e "${YELLOW}Full report available at: $latest_report${NC}"
      fi
    else
      status_message error "Security audit failed"
    fi
  else
    status_message error "Security audit script not found"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# =====================================
# System Controls Menu
# =====================================

# System controls menu
system_menu() {
  show_header
  echo -e "${BLUE}[⚙️] SYSTEM CONTROLS${NC}"
  echo -e "1. Update OSINT Tools"
  echo -e "2. System Status"
  echo -e "3. Data Management"
  echo -e "4. View Logs"
  echo -e "5. Power Management"
  echo -e "6. Run Security Audit"
  echo -e "9. Back to Main Menu"
  echo -e "0. Exit"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1) update_tools ;;
    2) check_system_status ;;
    3) manage_data ;;
    4) view_logs ;;
    5) power_management ;;
    6) run_security_audit ;;
    9) return 0 ;;
    0) exit 0 ;;
    *) 
      status_message error "Invalid option"
      sleep 1
      ;;
  esac
  
  # Return to system menu after function completes
  system_menu
  return 0
}