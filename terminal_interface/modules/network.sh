#!/bin/bash

# Network Scanning module for OSINT Command Center

# Run network scan
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
    local target_dir="$DATA_DIR/network/$target_safe"
    mkdir -p "$target_dir"
    
    section_header "Network Scan: $target"
    
    # Ask for scan type
    echo -e "1. ${BLUE}[🔍]${NC} Quick Scan (top 1000 ports)"
    echo -e "2. ${BLUE}[🔨]${NC} Full Scan (all ports, slower)"
    echo -e "3. ${BLUE}[💥]${NC} Comprehensive (all ports + service detection + scripts)"
    read_input "Select scan type: " scan_type validate_number
    
    # Run scan
    case $scan_type in
        1)
            # Quick scan
            echo -e "${YELLOW}Running quick port scan...${NC}"
            local cmd="nerdctl exec osint-network-scan rustscan -a $target --ulimit 5000 --batch-size 2500 --no-nmap -- -oX /opt/osint/data/network/$target_safe/quick_scan.xml"
            $cmd &
            show_spinner $! "Scanning top 1000 ports..."
            ;;
        2)
            # Full scan
            echo -e "${YELLOW}Running full port scan...${NC}"
            local cmd="nerdctl exec osint-network-scan rustscan -a $target --ulimit 5000 --batch-size 2500 --range 1-65535 --no-nmap -- -oX /opt/osint/data/network/$target_safe/full_scan.xml"
            $cmd &
            show_spinner $! "Scanning all ports..."
            ;;
        3)
            # Comprehensive scan
            echo -e "${YELLOW}Running comprehensive port scan...${NC}"
            local cmd="nerdctl exec osint-network-scan rustscan -a $target --ulimit 5000 --batch-size 2500 --range 1-65535 --no-nmap -- -sV -sC -A -oX /opt/osint/data/network/$target_safe/comprehensive_scan.xml"
            $cmd &
            show_spinner $! "Scanning all ports with service detection and scripts..."
            ;;
        *)
            status_message error "Invalid selection"
            sleep 2
            return
            ;;
    esac
    
    # Determine output file
    local scan_file=""
    case $scan_type in
        1) scan_file="$target_dir/quick_scan.xml" ;;
        2) scan_file="$target_dir/full_scan.xml" ;;
        3) scan_file="$target_dir/comprehensive_scan.xml" ;;
    esac
    
    # Extract results
    if [[ -f "$scan_file" ]]; then
        # Parse XML and extract open ports
        echo -e "${YELLOW}Extracting scan results...${NC}"
        
        # Parse XML with grep and sed (basic parsing)
        local open_ports=$(grep -oP 'portid="\K[0-9]+(?=".+state="open")' "$scan_file" || echo "")
        local port_count=$(echo "$open_ports" | wc -w)
        
        echo
        status_message success "Scan completed"
        echo
        echo -e "${BLUE}Results for $target:${NC}"
        echo -e "Found $port_count open ports"
        echo
        
        if [[ $port_count -gt 0 ]]; then
            echo -e "${YELLOW}Open ports:${NC}"
            
            # Get service information if available
            if grep -q "service name=" "$scan_file"; then
                # Extract port, service, version
                grep -A3 'state="open"' "$scan_file" | grep -E 'portid=|service name=' | 
                sed -n 'N;s/.*portid="\([0-9]*\)".*name="\([^"]*\)".*product="\([^"]*\)".*/Port \1: \2 (\3)/p;s/.*portid="\([0-9]*\)".*name="\([^"]*\)".*/Port \1: \2/p' | 
                head -10
                
                if [[ $port_count -gt 10 ]]; then
                    echo "... (more ports in scan results)"
                fi
            else
                # Just show port numbers
                echo "$open_ports" | tr ' ' '\n' | head -10
                
                if [[ $port_count -gt 10 ]]; then
                    echo "... (more ports in scan results)"
                fi
            fi
        else
            echo -e "${YELLOW}No open ports found${NC}"
        fi
        
        # Convert to human-readable output
        nerdctl exec osint-network-scan xsltproc "$scan_file" -o "$target_dir/scan_report.html"
    else
        status_message error "Scan failed or no results found"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Service detection
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
    local target_dir="$DATA_DIR/network/$target_safe"
    mkdir -p "$target_dir"
    
    section_header "Service Detection: $target"
    
    # Ask for ports
    read_input "Enter ports to scan (e.g., 22,80,443) or leave empty for top 1000: " ports
    
    # Format port parameter
    local port_param=""
    if [[ -n "$ports" ]]; then
        port_param="-p $ports"
    fi
    
    # Run nmap service detection
    echo -e "${YELLOW}Running service version detection...${NC}"
    local cmd="nerdctl exec osint-network-scan nmap $port_param -sV -sC $target -oX $target_dir/service_detection.xml"
    $cmd &
    show_spinner $! "Detecting service versions..."
    
    # Process results
    if [[ -f "$target_dir/service_detection.xml" ]]; then
        echo
        status_message success "Service detection completed"
        echo
        
        # Parse results
        local services=$(grep -A5 'state="open"' "$target_dir/service_detection.xml" | 
                        grep -E 'portid=|service name=|product=|version=' | 
                        tr '\n' ' ' | 
                        sed -E 's/<port |<\/port>/\n/g')
        
        echo -e "${BLUE}Detected services on $target:${NC}"
        echo
        
        # Process and display services
        echo "$services" | 
        grep 'state="open"' | 
        sed -E 's/.*portid="([^"]+)".*name="([^"]+)".*product="([^"]*)".*version="([^"]*)".*/Port \1: \2 \3 \4/g' | 
        sed -E 's/  +/ /g' | 
        sort -n -k2 -t ' '
        
        # Convert to human-readable output
        nerdctl exec osint-network-scan xsltproc "$target_dir/service_detection.xml" -o "$target_dir/service_report.html"
    else
        status_message error "Service detection failed or no results found"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Network reconnaissance
network_recon() {
    local target=""
    
    # Get target network range
    read_input "Enter target network range (e.g., 192.168.1.0/24): " target validate_ip required
    
    # Create target directory
    local target_safe=$(echo "$target" | tr '/' '_')
    local target_dir="$DATA_DIR/network/$target_safe"
    mkdir -p "$target_dir"
    
    section_header "Network Reconnaissance: $target"
    
    # Run host discovery
    echo -e "${YELLOW}Running host discovery...${NC}"
    local cmd="nerdctl exec osint-network-scan nmap -sn $target -oX $target_dir/host_discovery.xml"
    $cmd &
    show_spinner $! "Discovering hosts on the network..."
    
    # Process results
    if [[ -f "$target_dir/host_discovery.xml" ]]; then
        echo
        status_message success "Host discovery completed"
        echo
        
        # Parse results to find live hosts
        local live_hosts=$(grep -A1 "status state=\"up\"" "$target_dir/host_discovery.xml" | 
                          grep "addr=" | 
                          sed -E 's/.*addr="([^"]+)".*/\1/g')
        
        # Count hosts
        local host_count=$(echo "$live_hosts" | wc -l)
        
        echo -e "${BLUE}Network reconnaissance results for $target:${NC}"
        echo -e "Found $host_count live hosts"
        echo
        
        if [[ $host_count -gt 0 ]]; then
            echo -e "${YELLOW}Live hosts:${NC}"
            echo "$live_hosts" | head -20
            
            if [[ $host_count -gt 20 ]]; then
                echo "... (more hosts in scan results)"
            fi
            
            # Save to file
            echo "$live_hosts" > "$target_dir/live_hosts.txt"
            
            # Ask to perform service scan on discovered hosts
            echo
            read -p "Would you like to perform a service scan on these hosts? (y/N): " perform_service_scan
            
            if [[ "$perform_service_scan" == "y" || "$perform_service_scan" == "Y" ]]; then
                echo -e "${YELLOW}Running service scan on live hosts...${NC}"
                local live_hosts_param=$(echo "$live_hosts" | tr '\n' ',')
                
                # Remove trailing comma
                live_hosts_param=${live_hosts_param%,}
                
                local cmd="nerdctl exec osint-network-scan nmap -sV -sC -oX $target_dir/service_scan.xml $live_hosts_param"
                $cmd &
                show_spinner $! "Scanning services on live hosts..."
                
                # Process service scan results
                if [[ -f "$target_dir/service_scan.xml" ]]; then
                    status_message success "Service scan completed"
                    echo
                    echo -e "${BLUE}Notable services:${NC}"
                    
                    # Extract interesting services (web servers, SSH, etc.)
                    grep -A5 -E 'service name="http|service name="ssh|service name="ftp|service name="smtp|service name="dns' "$target_dir/service_scan.xml" | 
                    grep -E 'addr=|portid=|service name=' | 
                    tr '\n' ' ' | 
                    sed -E 's/<host |<\/host>/\n/g' | 
                    grep 'state="open"' | 
                    sed -E 's/.*addr="([^"]+)".*portid="([^"]+)".*name="([^"]+)".*/Host \1:\tPort \2 (\3)/g' | 
                    sort | 
                    head -20
                    
                    # Convert to human-readable output
                    nerdctl exec osint-network-scan xsltproc "$target_dir/service_scan.xml" -o "$target_dir/network_services.html"
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

# Vulnerability scanning
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
    local target_dir="$DATA_DIR/network/$target_safe"
    mkdir -p "$target_dir"
    
    section_header "Vulnerability Scan: $target"
    
    # Run nmap with vulnerability scripts
    echo -e "${YELLOW}Running vulnerability scan...${NC}"
    echo -e "${RED}Warning: This scan may trigger IDS/IPS alerts${NC}"
    echo
    
    read -p "Do you want to continue? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        status_message warning "Scan aborted"
        sleep 2
        return
    fi
    
    local cmd="nerdctl exec osint-network-scan nmap -sV --script vuln $target -oX $target_dir/vuln_scan.xml"
    $cmd &
    show_spinner $! "Scanning for vulnerabilities..."
    
    # Process results
    if [[ -f "$target_dir/vuln_scan.xml" ]]; then
        echo
        status_message success "Vulnerability scan completed"
        echo
        
        # Extract vulnerability information
        echo -e "${BLUE}Potential vulnerabilities for $target:${NC}"
        echo
        
        # Extract script output with vulnerabilities
        grep -A10 "id=\"vuln" "$target_dir/vuln_scan.xml" | 
        grep -E 'id="|output=' | 
        tr '\n' ' ' | 
        sed -E 's/<script |<\/script>/\n/g' | 
        grep 'output=' | 
        sed -E 's/.*id="([^"]+)".*output="([^"]+)".*/\1: \2/g' | 
        sed -E 's/&lt;/</g' | sed -E 's/&gt;/>/g' | sed -E 's/&quot;/"/g' | 
        head -20
        
        # Convert to human-readable output
        nerdctl exec osint-network-scan xsltproc "$target_dir/vuln_scan.xml" -o "$target_dir/vuln_report.html"
    else
        status_message error "Vulnerability scan failed or no results found"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Export network data
export_network_data() {
    # Check if any network scans have been performed
    if [[ ! -d "$DATA_DIR/network" || -z "$(ls -A "$DATA_DIR/network" 2>/dev/null)" ]]; then
        status_message error "No network data available for export"
        sleep 2
        return
    fi
    
    # List available targets
    section_header "Export Network Data"
    echo -e "${BLUE}Available targets:${NC}"
    echo
    
    # Get list of targets
    local targets=()
    if [ -d "$DATA_DIR/network" ]; then
        mapfile -t targets < <(ls -1 "$DATA_DIR/network")
    fi
    
    for i in "${!targets[@]}"; do
        echo -e "$((i+1)). ${targets[$i]}"
    done
    echo
    
    # Select target
    read_input "Select target (1-${#targets[@]}): " target_idx validate_number
    
    if [[ "$target_idx" -ge 1 && "$target_idx" -le "${#targets[@]}" ]]; then
        local selected_target="${targets[$((target_idx-1))]}"
        local target_dir="$DATA_DIR/network/$selected_target"
        
        # Create export directory
        local export_dir="$DATA_DIR/exports"
        mkdir -p "$export_dir"
        
        # Export filename with timestamp
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local export_file="$export_dir/network_${selected_target}_${timestamp}.tar.gz"
        
        # Create archive
        echo -e "${YELLOW}Creating export archive...${NC}"
        tar -czf "$export_file" -C "$DATA_DIR/network" "$selected_target"
        
        if [[ $? -eq 0 ]]; then
            status_message success "Network data exported to $export_file"
            echo
            echo -e "${BLUE}Export contains:${NC}"
            tar -tzf "$export_file" | grep -v "/$" | head -10
            
            if [[ $(tar -tzf "$export_file" | grep -v "/$" | wc -l) -gt 10 ]]; then
                echo "... (more files in archive)"
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
    display_header
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
        9) return ;;
        0) exit 0 ;;
        *) network_menu ;;
    esac
    
    # Return to network menu after function completes
    network_menu
}