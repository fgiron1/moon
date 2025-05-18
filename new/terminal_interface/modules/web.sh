#!/bin/bash

# Web Analysis module for OSINT Command Center

# Run website scanning
website_scan() {
    local url=""
    
    # Get URL
    read_input "Enter website URL: " url validate_url required
    
    # Create target directory
    local target_safe=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
    local target_dir="$DATA_DIR/web/$target_safe"
    mkdir -p "$target_dir"
    
    section_header "Website Scan: $url"
    
    # Run httpx in container to verify URL is accessible
    echo -e "${YELLOW}Verifying URL accessibility...${NC}"
    local cmd="nerdctl exec osint-web-analysis httpx -u $url -json -o $target_dir/httpx_results.json"
    $cmd &
    show_spinner $! "Checking website availability..."
    
    # Check if website is accessible
    if [[ ! -f "$target_dir/httpx_results.json" ]]; then
        status_message error "Website is not accessible"
        read -p "Press Enter to continue..." dummy
        return
    fi
    
    # Run nuclei in container for vulnerability scanning
    echo -e "${YELLOW}Running vulnerability scan...${NC}"
    local cmd="nerdctl exec osint-web-analysis nuclei -u $url -severity low,medium,high,critical -json -o $target_dir/nuclei_results.json"
    $cmd &
    show_spinner $! "Scanning for vulnerabilities..."
    
    # Run hakrawler in container for crawling
    echo -e "${YELLOW}Crawling website...${NC}"
    local cmd="nerdctl exec osint-web-analysis hakrawler -url $url -depth 2 -js -plain > $target_dir/hakrawler_results.txt"
    $cmd &
    show_spinner $! "Crawling and discovering website assets..."
    
    # Display results
    echo
    status_message success "Website scan completed"
    echo
    
    # Display vulnerabilities if found
    if [[ -f "$target_dir/nuclei_results.json" ]]; then
        echo -e "${BLUE}Vulnerabilities found:${NC}"
        
        # Parse JSON with jq if available, otherwise use grep
        if command -v jq >/dev/null 2>&1; then
            jq -r '.info.severity + ": " + .info.name' "$target_dir/nuclei_results.json" 2>/dev/null | sort | uniq | head -10
            
            local vuln_count=$(jq -r '.info.name' "$target_dir/nuclei_results.json" 2>/dev/null | wc -l)
            echo -e "${GREEN}Found $vuln_count potential vulnerabilities${NC}"
            
            if [[ $vuln_count -gt 10 ]]; then
                echo "... (more results in $target_dir/nuclei_results.json)"
            fi
        else
            grep -o '"name": "[^"]*".*"severity": "[^"]*"' "$target_dir/nuclei_results.json" | head -10
            
            local vuln_count=$(grep -o '"name": "[^"]*"' "$target_dir/nuclei_results.json" | wc -l)
            echo -e "${GREEN}Found $vuln_count potential vulnerabilities${NC}"
            
            if [[ $vuln_count -gt 10 ]]; then
                echo "... (more results in $target_dir/nuclei_results.json)"
            fi
        fi
    else
        echo -e "${YELLOW}No vulnerabilities found${NC}"
    fi
    
    echo
    
    # Display crawled URLs
    if [[ -f "$target_dir/hakrawler_results.txt" ]]; then
        echo -e "${BLUE}Discovered URLs:${NC}"
        head -10 "$target_dir/hakrawler_results.txt"
        
        local url_count=$(wc -l < "$target_dir/hakrawler_results.txt")
        echo -e "${GREEN}Found $url_count URLs${NC}"
        
        if [[ $url_count -gt 10 ]]; then
            echo "... (more results in $target_dir/hakrawler_results.txt)"
        fi
    else
        echo -e "${YELLOW}No URLs discovered${NC}"
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
    local target_dir="$DATA_DIR/web/$target_safe"
    mkdir -p "$target_dir"
    
    section_header "Technology Detection: $url"
    
    # Run whatweb in container
    echo -e "${YELLOW}Detecting website technologies...${NC}"
    local cmd="nerdctl exec osint-web-analysis whatweb -a 3 --log-json=$target_dir/whatweb_results.json $url"
    $cmd &
    show_spinner $! "Analyzing website technologies..."
    
    # Run httpx with tech detection
    echo -e "${YELLOW}Running additional technology detection...${NC}"
    local cmd="nerdctl exec osint-web-analysis httpx -u $url -json -o $target_dir/httpx_tech_results.json -tech-detect"
    $cmd &
    show_spinner $! "Identifying technologies and frameworks..."
    
    # Display results
    echo
    status_message success "Technology detection completed"
    echo
    
    # Display technologies if found
    if [[ -f "$target_dir/whatweb_results.json" ]]; then
        echo -e "${BLUE}Technologies detected:${NC}"
        
        # Parse JSON with jq if available, otherwise use grep
        if command -v jq >/dev/null 2>&1; then
            jq -r '.[0] | to_entries[] | select(.key != "target" and .key != "http_status" and .key != "plugins") | .key + ": " + (.value | tostring)' "$target_dir/whatweb_results.json" 2>/dev/null
            
            echo -e "\n${BLUE}Software/Frameworks:${NC}"
            jq -r '.[0].plugins | to_entries[] | .key' "$target_dir/whatweb_results.json" 2>/dev/null | head -15
        else
            grep -o '"[^"]*": \[{"version"' "$target_dir/whatweb_results.json" | cut -d'"' -f2 | head -15
        fi
    else
        echo -e "${YELLOW}No technology data from whatweb${NC}"
    fi
    
    echo
    
    # Display httpx technologies if found
    if [[ -f "$target_dir/httpx_tech_results.json" ]]; then
        echo -e "${BLUE}Additional technologies:${NC}"
        
        # Parse JSON with jq if available, otherwise use grep
        if command -v jq >/dev/null 2>&1; then
            jq -r '.technologies[]' "$target_dir/httpx_tech_results.json" 2>/dev/null | sort | uniq
        else
            grep -o '"technologies":\[[^]]*\]' "$target_dir/httpx_tech_results.json" | sed 's/"technologies":\[//g' | sed 's/\]//g' | sed 's/"//g' | tr ',' '\n'
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
    local target_dir="$DATA_DIR/web/$target_safe"
    mkdir -p "$target_dir"
    
    section_header "Content Discovery: $url"
    
    # Run feroxbuster in container
    echo -e "${YELLOW}Running directory brute force...${NC}"
    local cmd="nerdctl exec osint-web-analysis feroxbuster --url $url --depth 2 --silent -o $target_dir/ferox_results.txt"
    $cmd &
    show_spinner $! "Discovering hidden directories and files..."
    
    # Run hakrawler in container for JS file discovery
    echo -e "${YELLOW}Discovering JavaScript files...${NC}"
    local cmd="nerdctl exec osint-web-analysis hakrawler -url $url -depth 2 -js > $target_dir/js_files.txt"
    $cmd &
    show_spinner $! "Finding JavaScript files..."
    
    # Display results
    echo
    status_message success "Content discovery completed"
    echo
    
    # Display discovered directories and files
    if [[ -f "$target_dir/ferox_results.txt" ]]; then
        echo -e "${BLUE}Discovered directories and files:${NC}"
        grep -E "200|301|302" "$target_dir/ferox_results.txt" | head -15
        
        local total_found=$(grep -E "200|301|302" "$target_dir/ferox_results.txt" | wc -l)
        echo -e "${GREEN}Found $total_found resources${NC}"
        
        if [[ $total_found -gt 15 ]]; then
            echo "... (more results in $target_dir/ferox_results.txt)"
        fi
    else
        echo -e "${YELLOW}No directories or files discovered${NC}"
    fi
    
    echo
    
    # Display discovered JS files
    if [[ -f "$target_dir/js_files.txt" ]]; then
        echo -e "${BLUE}JavaScript files:${NC}"
        grep "\.js" "$target_dir/js_files.txt" | head -10
        
        local js_count=$(grep "\.js" "$target_dir/js_files.txt" | wc -l)
        echo -e "${GREEN}Found $js_count JavaScript files${NC}"
        
        if [[ $js_count -gt 10 ]]; then
            echo "... (more results in $target_dir/js_files.txt)"
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
    if [[ ! -d "$DATA_DIR/web" || -z "$(ls -A "$DATA_DIR/web" 2>/dev/null)" ]]; then
        status_message error "No web analysis data available for export"
        sleep 2
        return
    fi
    
    # List available websites
    section_header "Export Web Analysis Data"
    echo -e "${BLUE}Available websites:${NC}"
    echo
    
    # Get list of websites
    local websites=()
    if [ -d "$DATA_DIR/web" ]; then
        mapfile -t websites < <(ls -1 "$DATA_DIR/web")
    fi
    
    for i in "${!websites[@]}"; do
        echo -e "$((i+1)). ${websites[$i]}"
    done
    echo
    
    # Select website
    read_input "Select website (1-${#websites[@]}): " website_idx validate_number
    
    if [[ "$website_idx" -ge 1 && "$website_idx" -le "${#websites[@]}" ]]; then
        local selected_website="${websites[$((website_idx-1))]}"
        
        # Create export directory
        local export_dir="$DATA_DIR/exports"
        mkdir -p "$export_dir"
        
        # Export filename with timestamp
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local export_file="$export_dir/web_${selected_website}_${timestamp}.tar.gz"
        
        # Create archive
        echo -e "${YELLOW}Creating export archive...${NC}"
        tar -czf "$export_file" -C "$DATA_DIR/web" "$selected_website"
        
        if [[ $? -eq 0 ]]; then
            status_message success "Web analysis data exported to $export_file"
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
    display_header
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
        9) return ;;
        0) exit 0 ;;
        *) web_menu ;;
    esac
    
    # Return to web menu after function completes
    web_menu
}