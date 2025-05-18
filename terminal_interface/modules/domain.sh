#!/bin/bash

# Domain Intelligence module for OSINT Command Center

# Run domain reconnaissance
domain_recon() {
    local domain=""
    
    # Get domain
    read_input "Enter domain to scan: " domain validate_domain required
    
    # Create target directory
    local target_dir="$DATA_DIR/domain/$domain"
    mkdir -p "$target_dir"
    
    section_header "Domain Reconnaissance: $domain"
    
    # Run amass in container
    echo -e "${YELLOW}Running Amass passive scan...${NC}"
    local amass_cmd="nerdctl exec osint-domain-intel amass enum -passive -d $domain -o /opt/osint/data/domain/$domain/amass_passive.txt"
    $amass_cmd &
    show_spinner $! "Gathering passive reconnaissance data..."
    
    # Run subfinder in container
    echo -e "${YELLOW}Running Subfinder scan...${NC}"
    local subfinder_cmd="nerdctl exec osint-domain-intel subfinder -d $domain -o /opt/osint/data/domain/$domain/subfinder.txt"
    $subfinder_cmd &
    show_spinner $! "Discovering subdomains..."
    
    # Run dnsx in container for DNS resolution
    echo -e "${YELLOW}Running DNS resolution...${NC}"
    local dnsx_cmd="nerdctl exec osint-domain-intel dnsx -l /opt/osint/data/domain/$domain/subfinder.txt -json -o /opt/osint/data/domain/$domain/dns_resolution.json"
    $dnsx_cmd &
    show_spinner $! "Resolving DNS records..."
    
    # Display results
    echo
    status_message success "Domain reconnaissance completed"
    echo
    echo -e "${BLUE}Found subdomains:${NC}"
    
    if [[ -f "$target_dir/subfinder.txt" ]]; then
        wc -l "$target_dir/subfinder.txt" | awk '{print $1 " subdomains discovered"}'
        head -n 5 "$target_dir/subfinder.txt"
        
        if [[ $(wc -l < "$target_dir/subfinder.txt") -gt 5 ]]; then
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
    local target_dir="$DATA_DIR/domain/$domain"
    mkdir -p "$target_dir"
    
    section_header "Subdomain Enumeration: $domain"
    
    # Ask for enumeration type
    echo -e "1. ${BLUE}[🔍]${NC} Passive (fast, no direct contact with target)"
    echo -e "2. ${BLUE}[🔨]${NC} Active (slower, directly queries target)"
    echo -e "3. ${BLUE}[💥]${NC} Aggressive (comprehensive, very noisy)"
    read_input "Select enumeration type: " enum_type validate_number
    
    case $enum_type in
        1)
            # Passive enumeration
            echo -e "${YELLOW}Running passive subdomain enumeration...${NC}"
            local cmd="nerdctl exec osint-domain-intel subfinder -d $domain -o /opt/osint/data/domain/$domain/passive_subdomains.txt"
            $cmd &
            show_spinner $! "Gathering subdomain intelligence..."
            ;;
        2)
            # Active enumeration
            echo -e "${YELLOW}Running active subdomain enumeration...${NC}"
            local cmd="nerdctl exec osint-domain-intel amass enum -active -d $domain -o /opt/osint/data/domain/$domain/active_subdomains.txt"
            $cmd &
            show_spinner $! "Actively enumerating subdomains..."
            ;;
        3)
            # Aggressive enumeration
            echo -e "${YELLOW}Running aggressive subdomain enumeration...${NC}"
            local cmd="nerdctl exec osint-domain-intel amass enum -active -brute -d $domain -o /opt/osint/data/domain/$domain/aggressive_subdomains.txt"
            $cmd &
            show_spinner $! "Aggressively enumerating subdomains..."
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
    
    # Determine which file to look at
    local result_file=""
    case $enum_type in
        1) result_file="$target_dir/passive_subdomains.txt" ;;
        2) result_file="$target_dir/active_subdomains.txt" ;;
        3) result_file="$target_dir/aggressive_subdomains.txt" ;;
    esac
    
    if [[ -f "$result_file" ]]; then
        wc -l "$result_file" | awk '{print $1 " subdomains discovered"}'
        echo
        head -n 10 "$result_file"
        
        if [[ $(wc -l < "$result_file") -gt 10 ]]; then
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
    local target_dir="$DATA_DIR/domain/$domain"
    mkdir -p "$target_dir"
    
    section_header "DNS Analysis: $domain"
    
    # Run dnsx with common DNS record types
    echo -e "${YELLOW}Running DNS record analysis...${NC}"
    local cmd="nerdctl exec osint-domain-intel bash -c \"echo $domain | dnsx -a -aaaa -cname -mx -ns -soa -txt -json -o /opt/osint/data/domain/$domain/dns_records.json\""
    $cmd &
    show_spinner $! "Retrieving DNS records..."
    
    # Parse and display results
    if [[ -f "$target_dir/dns_records.json" ]]; then
        echo
        status_message success "DNS analysis completed"
        echo
        
        # Format and display results
        echo -e "${BLUE}DNS Records for $domain:${NC}"
        echo
        
        # A Records
        echo -e "${YELLOW}A Records:${NC}"
        grep -o '"a":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"a":\[\|"\|\]//g' | sed 's/,/\n/g'
        echo
        
        # AAAA Records
        echo -e "${YELLOW}AAAA Records:${NC}"
        grep -o '"aaaa":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"aaaa":\[\|"\|\]//g' | sed 's/,/\n/g'
        echo
        
        # CNAME Records
        echo -e "${YELLOW}CNAME Records:${NC}"
        grep -o '"cname":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"cname":\[\|"\|\]//g' | sed 's/,/\n/g'
        echo
        
        # MX Records
        echo -e "${YELLOW}MX Records:${NC}"
        grep -o '"mx":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"mx":\[\|"\|\]//g' | sed 's/,/\n/g'
        echo
        
        # NS Records
        echo -e "${YELLOW}NS Records:${NC}"
        grep -o '"ns":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"ns":\[\|"\|\]//g' | sed 's/,/\n/g'
        echo
        
        # TXT Records
        echo -e "${YELLOW}TXT Records:${NC}"
        grep -o '"txt":\[[^]]*\]' "$target_dir/dns_records.json" | sed 's/"txt":\[\|"\|\]//g' | sed 's/,/\n/g'
        echo
    else
        status_message error "DNS analysis failed or no records found"
    fi
    
    read -p "Press Enter to continue..." dummy
}

# Domain intelligence menu
domain_menu() {
    display_header
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
        9) return ;;
        0) exit 0 ;;
        *) domain_menu ;;
    esac
    
    # Return to domain menu after function completes
    domain_menu
}

# Export domain data
export_domain_data() {
    # Check if any domains have been scanned
    if [[ ! -d "$DATA_DIR/domain" || -z "$(ls -A "$DATA_DIR/domain")" ]]; then
        status_message error "No domain data available for export"
        sleep 2
        return
    fi
    
    # List available domains
    section_header "Export Domain Data"
    echo -e "${BLUE}Available domains:${NC}"
    echo
    
    # Get list of domains
    local domains=()
    mapfile -t domains < <(ls -1 "$DATA_DIR/domain")
    
    for i in "${!domains[@]}"; do
        echo -e "$((i+1)). ${domains[$i]}"
    done
    echo
    
    # Select domain
    read_input "Select domain (1-${#domains[@]}): " domain_idx validate_number
    
    if [[ "$domain_idx" -ge 1 && "$domain_idx" -le "${#domains[@]}" ]]; then
        local selected_domain="${domains[$((domain_idx-1))]}"
        local domain_dir="$DATA_DIR/domain/$selected_domain"
        
        # Create export directory
        local export_dir="$DATA_DIR/exports"
        mkdir -p "$export_dir"
        
        # Export filename with timestamp
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local export_file="$export_dir/${selected_domain}_export_$timestamp.tar.gz"
        
        # Create archive
        echo -e "${YELLOW}Creating export archive...${NC}"
        tar -czf "$export_file" -C "$DATA_DIR/domain" "$selected_domain"
        
        if [[ $? -eq 0 ]]; then
            status_message success "Domain data exported to $export_file"
            echo
            echo -e "${BLUE}Export contains:${NC}"
            tar -tzf "$export_file" | grep -v "/$" | head -n 10
            
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