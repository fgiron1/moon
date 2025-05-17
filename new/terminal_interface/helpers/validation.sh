#!/bin/bash

# Validation functions for OSINT Command Center

# Validate numeric input
validate_number() {
    local input=$1
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Please enter a valid number${NC}"
        return 1
    fi
    return 0
}

# Validate IP address
validate_ip() {
    local ip=$1
    local valid_ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$"
    if ! [[ $ip =~ $valid_ip_regex ]]; then
        echo -e "${RED}Error: Invalid IP format. Use format like 192.168.1.1 or 192.168.1.0/24${NC}"
        return 1
    fi
    
    # Validate each octet
    IFS='.' read -r -a octets <<< "${ip%%/*}" # Strip CIDR notation if present
    for octet in "${octets[@]}"; do
        if [[ "$octet" -gt 255 ]]; then
            echo -e "${RED}Error: IP octets must be between 0-255${NC}"
            return 1
        fi
    done
    
    # Validate CIDR if present
    if [[ $ip == */* ]]; then
        local cidr="${ip#*/}"
        if [[ "$cidr" -gt 32 ]]; then
            echo -e "${RED}Error: CIDR must be between 0-32${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Validate domain name
validate_domain() {
    local domain=$1
    local valid_domain_regex="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
    if ! [[ $domain =~ $valid_domain_regex ]]; then
        echo -e "${RED}Error: Invalid domain format. Use format like example.com${NC}"
        return 1
    fi
    return 0
}

# Validate URL
validate_url() {
    local url=$1
    local valid_url_regex="^(https?|ftp)://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/[a-zA-Z0-9._%/-]*)?$"
    if ! [[ $url =~ $valid_url_regex ]]; then
        echo -e "${RED}Error: Invalid URL format. Use format like https://example.com${NC}"
        return 1
    fi
    return 0
}

# Validate email address
validate_email() {
    local email=$1
    local valid_email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    if ! [[ $email =~ $valid_email_regex ]]; then
        echo -e "${RED}Error: Invalid email format. Use format like user@example.com${NC}"
        return 1
    fi
    return 0
}

# Validate username (alphanumeric and some special chars)
validate_username() {
    local username=$1
    local valid_username_regex="^[a-zA-Z0-9_.@-]{1,30}$"
    if ! [[ $username =~ $valid_username_regex ]]; then
        echo -e "${RED}Error: Username should be 1-30 characters and contain only letters, numbers, and _.@-${NC}"
        return 1
    fi
    return 0
}

# Validate phone number (international format)
validate_phone() {
    local phone=$1
    local valid_phone_regex="^\+[0-9]{1,15}$"
    if ! [[ $phone =~ $valid_phone_regex ]]; then
        echo -e "${RED}Error: Invalid phone format. Use international format like +12345678901${NC}"
        return 1
    fi
    return 0
}

# Validate network interface
validate_interface() {
    local iface=$1
    if ! ip link show "$iface" &>/dev/null; then
        echo -e "${RED}Error: Network interface '$iface' does not exist${NC}"
        return 1
    fi
    return 0
}

# Validate file exists
validate_file_exists() {
    local file=$1
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: File '$file' does not exist${NC}"
        return 1
    fi
    return 0
}

# Validate directory exists
validate_dir_exists() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Error: Directory '$dir' does not exist${NC}"
        return 1
    fi
    return 0
}