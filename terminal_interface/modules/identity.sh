#!/bin/bash

# Identity Research module for OSINT Command Center

# Run username search across platforms
username_search() {
    local username=""
    
    # Get username
    read_input "Enter username to search: " username validate_username required
    
    # Create target directory
    local target_dir="$DATA_DIR/identity/username/$username"
    mkdir -p "$target_dir"
    
    section_header "Username Search: $username"
    
    # Run sherlock in container
    echo -e "${YELLOW}Running Sherlock search...${NC}"
    local cmd="nerdctl exec osint-identity-research sherlock $username --output $target_dir/sherlock_results.txt"
    $cmd &
    show_spinner $! "Searching for username across platforms..."
    
    # Run maigret in container
    echo -e "${YELLOW}Running Maigret search...${NC}"
    local cmd="nerdctl exec osint-identity-research maigret $username --output $target_dir/maigret_results.json --json"
    $cmd &
    show_spinner $! "Performing advanced username search..."
    
    # Display results
    echo
    status_message success "Username search completed"
    echo
    
    if [[ -f "$target_dir/sherlock_results.txt" ]]; then
        echo -e "${BLUE}Sherlock results:${NC}"
        grep -E "FOUND|ERROR" "$target_dir/sherlock_results.txt" | head -10
        
        local total_found=$(grep "FOUND" "$target_dir/sherlock_results.txt" | wc -l)
        echo -e "${GREEN}Found $username on $total_found platforms${NC}"
        
        if [[ $(grep -E "FOUND|ERROR" "$target_dir/sherlock_results.txt" | wc -l) -gt 10 ]]; then
            echo "... (more results in $target_dir/sherlock_results.txt)"
        fi
    else
        echo "No Sherlock results found"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Email account investigation
email_investigation() {
    local email=""
    
    # Get email
    read_input "Enter email address: " email validate_email required
    
    # Create target directory
    local target_dir="$DATA_DIR/identity/email/$email"
    mkdir -p "$target_dir"
    
    section_header "Email Investigation: $email"
    
    # Run holehe in container
    echo -e "${YELLOW}Running Holehe to find accounts...${NC}"
    local cmd="nerdctl exec osint-identity-research holehe $email --output $target_dir/holehe_results.json"
    $cmd &
    show_spinner $! "Searching for accounts using this email..."
    
    # Run email header analysis
    echo -e "${YELLOW}Analyzing email metadata...${NC}"
    
    # Display results
    echo
    status_message success "Email investigation completed"
    echo
    
    if [[ -f "$target_dir/holehe_results.json" ]]; then
        echo -e "${BLUE}Found accounts:${NC}"
        
        # Parse JSON with jq if available, otherwise use grep
        if command -v jq >/dev/null 2>&1; then
            jq -r '.[] | select(.exists==true) | .name' "$target_dir/holehe_results.json" | head -10
            
            local total_found=$(jq -r '.[] | select(.exists==true) | .name' "$target_dir/holehe_results.json" | wc -l)
            echo -e "${GREEN}Found $email on $total_found services${NC}"
        else
            grep -o '"name": "[^"]*".*"exists": true' "$target_dir/holehe_results.json" | head -10
        fi
    else
        echo "No Holehe results found"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Phone number analysis
phone_analysis() {
    local phone=""
    
    # Get phone number
    read_input "Enter phone number (with country code, e.g., +1234567890): " phone validate_phone required
    
    # Create target directory
    local target_dir="$DATA_DIR/identity/phone/$phone"
    mkdir -p "$target_dir"
    
    section_header "Phone Number Analysis: $phone"
    
    # Run phoneinfoga in container
    echo -e "${YELLOW}Running PhoneInfoga analysis...${NC}"
    local cmd="nerdctl exec osint-identity-research phoneinfoga scan -n $phone -o $target_dir/phoneinfoga_results.json"
    $cmd &
    show_spinner $! "Analyzing phone number data..."
    
    # Display results
    echo
    status_message success "Phone number analysis completed"
    echo
    
    if [[ -f "$target_dir/phoneinfoga_results.json" ]]; then
        echo -e "${BLUE}Phone number information:${NC}"
        
        # Parse JSON with jq if available, otherwise display file
        if command -v jq >/dev/null 2>&1; then
            echo -e "${YELLOW}Number format:${NC} $(jq -r '.number.format // "Unknown"' "$target_dir/phoneinfoga_results.json")"
            echo -e "${YELLOW}Local format:${NC} $(jq -r '.number.local_format // "Unknown"' "$target_dir/phoneinfoga_results.json")"
            echo -e "${YELLOW}Country:${NC} $(jq -r '.number.country // "Unknown"' "$target_dir/phoneinfoga_results.json")"
            echo -e "${YELLOW}Carrier:${NC} $(jq -r '.carrier // "Unknown"' "$target_dir/phoneinfoga_results.json")"
            
            echo -e "\n${YELLOW}Reputation:${NC}"
            jq -r '.reputation | to_entries[] | .key + ": " + (.value | tostring)' "$target_dir/phoneinfoga_results.json" 2>/dev/null || echo "No reputation data available"
        else
            cat "$target_dir/phoneinfoga_results.json"
        fi
    else
        echo "No PhoneInfoga results found"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Social media profile discovery
social_media_discovery() {
    local target=""
    
    # Get target
    read_input "Enter target (username, email, full name): " target
    
    # Create target directory
    local target_safe=$(echo "$target" | tr ' ' '_')
    local target_dir="$DATA_DIR/identity/social/$target_safe"
    mkdir -p "$target_dir"
    
    section_header "Social Media Discovery: $target"
    
    # Run bbot in container
    echo -e "${YELLOW}Running bbot social module...${NC}"
    local cmd="nerdctl exec osint-identity-research bbot -t '$target' -m social -f json -o $target_dir/bbot_social.json"
    $cmd &
    show_spinner $! "Discovering social media profiles..."
    
    # Display results
    echo
    status_message success "Social media discovery completed"
    echo
    
    if [[ -f "$target_dir/bbot_social.json" ]]; then
        echo -e "${BLUE}Social media profiles:${NC}"
        
        # Parse JSON with jq if available, otherwise use grep
        if command -v jq >/dev/null 2>&1; then
            jq -r '.events[] | select(.module | contains("social")) | .data.url' "$target_dir/bbot_social.json" 2>/dev/null | sort | uniq | head -10
        else
            grep -o '"url": "[^"]*"' "$target_dir/bbot_social.json" | sort | uniq | head -10
        fi
        
        # Count total social profiles
        local total_profiles=0
        if command -v jq >/dev/null 2>&1; then
            total_profiles=$(jq -r '.events[] | select(.module | contains("social")) | .data.url' "$target_dir/bbot_social.json" 2>/dev/null | sort | uniq | wc -l)
        else
            total_profiles=$(grep -o '"url": "[^"]*"' "$target_dir/bbot_social.json" | sort | uniq | wc -l)
        fi
        
        echo -e "${GREEN}Found $total_profiles social media profiles${NC}"
        
        if [[ $total_profiles -gt 10 ]]; then
            echo "... (more results in $target_dir/bbot_social.json)"
        fi
    else
        echo "No bbot results found"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Export identity data
export_identity_data() {
    # Check if any identity data exists
    if [[ ! -d "$DATA_DIR/identity" || -z "$(ls -A "$DATA_DIR/identity" 2>/dev/null)" ]]; then
        status_message error "No identity data available for export"
        sleep 2
        return
    fi
    
    # List available identity types
    section_header "Export Identity Data"
    echo -e "${BLUE}Available identity data types:${NC}"
    echo
    
    # Get list of identity types
    local types=()
    if [ -d "$DATA_DIR/identity" ]; then
        mapfile -t types < <(ls -1 "$DATA_DIR/identity")
    fi
    
    for i in "${!types[@]}"; do
        echo -e "$((i+1)). ${types[$i]}"
    done
    echo
    
    # Select type
    read_input "Select type (1-${#types[@]}): " type_idx validate_number
    
    if [[ "$type_idx" -ge 1 && "$type_idx" -le "${#types[@]}" ]]; then
        local selected_type="${types[$((type_idx-1))]}"
        
        # List available targets for the selected type
        echo -e "${BLUE}Available targets for ${selected_type}:${NC}"
        echo
        
        local targets=()
        if [ -d "$DATA_DIR/identity/$selected_type" ]; then
            mapfile -t targets < <(ls -1 "$DATA_DIR/identity/$selected_type")
        fi
        
        if [ ${#targets[@]} -eq 0 ]; then
            status_message error "No targets found for ${selected_type}"
            sleep 2
            return
        fi
        
        for i in "${!targets[@]}"; do
            echo -e "$((i+1)). ${targets[$i]}"
        done
        echo
        
        # Select target
        read_input "Select target (1-${#targets[@]}): " target_idx validate_number
        
        if [[ "$target_idx" -ge 1 && "$target_idx" -le "${#targets[@]}" ]]; then
            local selected_target="${targets[$((target_idx-1))]}"
            
            # Create export directory
            local export_dir="$DATA_DIR/exports"
            mkdir -p "$export_dir"
            
            # Export filename with timestamp
            local timestamp=$(date +%Y%m%d_%H%M%S)
            local export_file="$export_dir/${selected_type}_${selected_target}_${timestamp}.tar.gz"
            
            # Create archive
            echo -e "${YELLOW}Creating export archive...${NC}"
            tar -czf "$export_file" -C "$DATA_DIR/identity/$selected_type" "$selected_target"
            
            if [[ $? -eq 0 ]]; then
                status_message success "Identity data exported to $export_file"
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

# Person investigation menu
person_investigation_menu() {
    display_header
    echo -e "${BLUE}[👤] PERSON INVESTIGATION${NC}"
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
        9) return ;;
        0) exit 0 ;;
        *) person_investigation_menu ;;
    esac
    
    # Return to identity menu after function completes
    person_investigation_menu
}