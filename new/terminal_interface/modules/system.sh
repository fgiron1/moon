#!/bin/bash

# System Control module for OSINT Command Center

# Function to update OSINT tools
update_tools() {
    section_header "Update OSINT Tools"
    
    echo -e "${YELLOW}Updating all OSINT tools...${NC}"
    sudo $SYSTEM_SCRIPT update
    
    status_message success "OSINT tools updated successfully"
    echo
    read -p "Press Enter to continue..." dummy
}

# Function to check system status
check_system_status() {
    section_header "System Status"
    
    # Check container status
    echo -e "${BLUE}Container Status:${NC}"
    sudo $CONTAINER_SCRIPT status
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
    
    read -p "Press Enter to continue..." dummy
}

# Function to manage data
manage_data() {
    section_header "Data Management"
    
    echo -e "1. List Data Directories"
    echo -e "2. Backup Data"
    echo -e "3. Secure Data Wipe"
    echo -e "4. View Disk Usage"
    echo -e "5. Back"
    echo
    
    read_input "Select option: " option validate_number
    
    case $option in
        1)
            section_header "Data Directories"
            
            echo -e "${BLUE}Target Data:${NC}"
            ls -lah "$DATA_DIR/targets/" 2>/dev/null || echo "No target data found"
            echo
            
            echo -e "${BLUE}Exported Data:${NC}"
            ls -lah "$DATA_DIR/exports/" 2>/dev/null || echo "No exported data found"
            echo
            
            echo -e "${BLUE}Reports:${NC}"
            ls -lah "$DATA_DIR/reports/" 2>/dev/null || echo "No reports found"
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
            mkdir -p "$backup_dir"
            
            echo -e "${YELLOW}Creating backup...${NC}"
            tar -czf "$backup_file" -C "$DATA_DIR" targets exports reports 2>/dev/null
            
            if [[ $? -eq 0 && -f "$backup_file" ]]; then
                status_message success "Backup created successfully: $backup_file"
                echo -e "${YELLOW}Backup size: $(du -h "$backup_file" | cut -f1)${NC}"
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
                    if [[ -d "$DATA_DIR/targets" && "$(ls -A "$DATA_DIR/targets" 2>/dev/null)" ]]; then
                        local targets=()
                        mapfile -t targets < <(ls -1 "$DATA_DIR/targets")
                        
                        for i in "${!targets[@]}"; do
                            echo -e "$((i+1)). ${targets[$i]}"
                        done
                        echo
                        
                        read_input "Select target to wipe (1-${#targets[@]}): " target_idx validate_number
                        
                        if [[ "$target_idx" -ge 1 && "$target_idx" -le "${#targets[@]}" ]]; then
                            local selected_target="${targets[$((target_idx-1))]}"
                            
                            echo -e "${RED}You are about to securely wipe target: $selected_target${NC}"
                            read -p "Type the target name to confirm: " confirm
                            
                            if [[ "$confirm" == "$selected_target" ]]; then
                                echo -e "${YELLOW}Wiping target data...${NC}"
                                
                                # Use secure-delete if available, otherwise use rm
                                if command -v srm >/dev/null 2>&1; then
                                    srm -r "$DATA_DIR/targets/$selected_target"
                                else
                                    rm -rf "$DATA_DIR/targets/$selected_target"
                                fi
                                
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
                        if command -v srm >/dev/null 2>&1; then
                            srm -r "$DATA_DIR/exports/"*
                        else
                            rm -rf "$DATA_DIR/exports/"*
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
                        if command -v srm >/dev/null 2>&1; then
                            srm -r "$DATA_DIR/targets/"* "$DATA_DIR/exports/"* "$DATA_DIR/reports/"* 2>/dev/null
                        else
                            rm -rf "$DATA_DIR/targets/"* "$DATA_DIR/exports/"* "$DATA_DIR/reports/"* 2>/dev/null
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
            du -h -d 1 "$DATA_DIR" | sort -hr
            echo
            
            echo -e "${BLUE}Detailed usage:${NC}"
            echo -e "${YELLOW}Targets:${NC} $(du -sh "$DATA_DIR/targets" 2>/dev/null | cut -f1 || echo "N/A")"
            echo -e "${YELLOW}Exports:${NC} $(du -sh "$DATA_DIR/exports" 2>/dev/null | cut -f1 || echo "N/A")"
            echo -e "${YELLOW}Reports:${NC} $(du -sh "$DATA_DIR/reports" 2>/dev/null | cut -f1 || echo "N/A")"
            echo -e "${YELLOW}Backups:${NC} $(du -sh "$DATA_DIR/backups" 2>/dev/null | cut -f1 || echo "N/A")"
            echo
            
            echo -e "${BLUE}System disk usage:${NC}"
            df -h /
            
            echo
            read -p "Press Enter to continue..." dummy
            manage_data
            ;;
        5)
            return
            ;;
        *)
            status_message error "Invalid option"
            sleep 1
            manage_data
            ;;
    esac
}

# Function to view system logs
view_logs() {
    section_header "System Logs"
    
    echo -e "1. Container Logs"
    echo -e "2. Security Logs"
    echo -e "3. System Logs"
    echo -e "4. Application Logs"
    echo -e "5. Back"
    echo
    
    read_input "Select option: " option validate_number
    
    case $option in
        1)
            section_header "Container Logs"
            
            # List containers
            echo -e "${BLUE}Available containers:${NC}"
            sudo nerdctl ps --format "{{.Names}}" | grep "osint-" | nl -w2 -s". "
            echo
            
            read -input "Select container number (or 0 to go back): " container_idx validate_number
            
            if [[ "$container_idx" -gt 0 ]]; then
                # Get container name by index
                local container_name=$(sudo nerdctl ps --format "{{.Names}}" | grep "osint-" | sed -n "${container_idx}p")
                
                if [[ -n "$container_name" ]]; then
                    echo -e "${YELLOW}Showing logs for $container_name:${NC}"
                    echo
                    sudo nerdctl logs --tail 100 "$container_name"
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
            find "$DATA_DIR/logs" -type f -name "*.log" 2>/dev/null | nl -w2 -s". "
            echo
            
            read_input "Select log file number (or 0 to go back): " log_idx validate_number
            
            if [[ "$log_idx" -gt 0 ]]; then
                # Get log file by index
                local log_file=$(find "$DATA_DIR/logs" -type f -name "*.log" 2>/dev/null | sed -n "${log_idx}p")
                
                if [[ -n "$log_file" && -f "$log_file" ]]; then
                    echo -e "${YELLOW}Showing log file: $log_file${NC}"
                    echo
                    tail -50 "$log_file"
                else
                    status_message error "Invalid log file selection"
                fi
            fi
            ;;
        5)
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

# Function to power management
power_management() {
    section_header "Power Management"
    
    echo -e "${RED}WARNING: These operations affect the server${NC}"
    echo -e "1. Restart server"
    echo -e "2. Shutdown server"
    echo -e "3. Restart container services"
    echo -e "4. Back"
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
            sudo $CONTAINER_SCRIPT restart
            status_message success "Container services restarted"
            ;;
        4)
            return
            ;;
        *)
            status_message error "Invalid option"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..." dummy
}

# System controls menu
system_menu() {
    display_header
    echo -e "${BLUE}[⚙️] SYSTEM CONTROLS${NC}"
    echo -e "1. Update OSINT Tools"
    echo -e "2. System Status"
    echo -e "3. Data Management"
    echo -e "4. View Logs"
    echo -e "5. Power Management"
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
        9) return ;;
        0) exit 0 ;;
        *) system_menu ;;
    esac
    
    # Return to system menu after function completes
    system_menu
}