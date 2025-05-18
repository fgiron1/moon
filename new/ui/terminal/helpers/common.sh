#!/bin/bash

# ui/terminal/helpers/common.sh
# Consolidated helper functions for OSINT Command Center Terminal Interface

# =====================================
# Color and Display Functions
# =====================================

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Terminal width
TERM_WIDTH=$(tput cols)

# Show progress spinner
show_spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    
    tput civis  # Hide cursor
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    
    printf "    \r"
    tput cnorm  # Show cursor
}

# Display status with color
status_message() {
    local status=$1
    local message=$2
    
    case $status in
        success)
            echo -e "${GREEN}✓ $message${NC}"
            ;;
        warning)
            echo -e "${YELLOW}⚠ $message${NC}"
            ;;
        error)
            echo -e "${RED}✗ $message${NC}"
            ;;
        info)
            echo -e "${BLUE}ℹ $message${NC}"
            ;;
        *)
            echo -e "$message"
            ;;
    esac
}

# Center text in terminal
center_text() {
    local text="$1"
    local width=${2:-$TERM_WIDTH}
    local padding=$(( (width - ${#text}) / 2 ))
    
    printf "%${padding}s%s\n" "" "$text"
}

# Display section header
section_header() {
    local title="$1"
    local width=${2:-$TERM_WIDTH}
    
    echo
    echo -e "${BLUE}$(printf '%*s' $width | tr ' ' '=')${NC}"
    center_text "$title" $width
    echo -e "${BLUE}$(printf '%*s' $width | tr ' ' '=')${NC}"
    echo
}

# Display standard header
display_header() {
    clear
    
    # Get current system info
    vpn_status=$(sudo vpn status 2>/dev/null | grep -q "active" && echo "${GREEN}ACTIVE${NC}" || echo "${RED}INACTIVE${NC}")
    container_count=$(sudo nerdctl ps | grep "osint-" | wc -l)
    
    # Display header
    width=$(tput cols)
    title="OSINT COMMAND CENTER"
    
    # Center the title
    printf "%*s\n" $(( (width + ${#title}) / 2)) "$title"
    printf "%*s\n" $width | tr " " "="
    
    echo -e "VPN: ${vpn_status} | Containers: ${container_count} | $(date '+%Y-%m-%d %H:%M')"
    printf "%*s\n" $width | tr " " "-"
}

# Display results in table format
display_table() {
    local header=("$@")
    local cols=${#header[@]}
    local data=()
    local col_widths=()
    
    # Initialize column widths based on header
    for i in "${!header[@]}"; do
        col_widths[$i]=${#header[$i]}
    done
    
    # Read data rows
    local row=()
    local line=""
    
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Split line into fields
        IFS='|' read -r -a row <<< "$line"
        
        # Update column widths if needed
        for i in "${!row[@]}"; do
            if [ $i -lt $cols ] && [ ${#row[$i]} -gt ${col_widths[$i]} ]; then
                col_widths[$i]=${#row[$i]}
            fi
        done
        
        # Add row to data
        data+=("${row[@]}")
    done
    
    # Print header
    for i in "${!header[@]}"; do
        printf "%-$((col_widths[$i] + 2))s" "${header[$i]}"
    done
    echo
    
    # Print separator
    for i in "${!col_widths[@]}"; do
        printf "%s" "$(printf '%*s' $((col_widths[$i] + 2)) | tr ' ' '-')"
    done
    echo
    
    # Print data
    for ((i=0; i<${#data[@]}; i+=cols)); do
        for j in $(seq 0 $((cols-1))); do
            printf "%-$((col_widths[$j] + 2))s" "${data[$i+$j]}"
        done
        echo
    done
}

# Display paged output
paged_output() {
    local content="$1"
    local lines_per_page=${2:-10}
    local current_line=0
    local total_lines=$(echo -e "$content" | wc -l)
    
    while [ $current_line -lt $total_lines ]; do
        # Display current page
        echo -e "$content" | tail -n +$((current_line + 1)) | head -n $lines_per_page
        
        current_line=$((current_line + lines_per_page))
        
        # Check if we've reached the end
        if [ $current_line -ge $total_lines ]; then
            break
        fi
        
        # Prompt for next page
        read -p "--- Press Enter for more, 'q' to quit --- " input
        if [[ "$input" == "q" ]]; then
            break
        fi
    done
}

# Display countdown timer
countdown() {
    local seconds=$1
    local message=${2:-"Continuing in"}
    
    for ((i=seconds; i>=1; i--)); do
        printf "\r%s %d seconds..." "$message" $i
        sleep 1
    done
    printf "\r%*s\r" $((${#message} + 15)) ""
}

# Get status information for VPN, Tor, etc.
get_vpn_status() {
    if vpn status | grep -q "VPN is active"; then
        echo -e "${GREEN}●${NC} Connected"
    else
        echo -e "${RED}●${NC} Disconnected"
    fi
}

get_tor_status() {
    if systemctl is-active tor >/dev/null && tor-control status | grep -q "Transparent routing is enabled"; then
        echo -e "${GREEN}●${NC} Active"
    else
        echo -e "${RED}●${NC} Inactive"
    fi
}

# =====================================
# Input Handling Functions
# =====================================

# Read input with validation
read_input() {
    local prompt=$1
    local var_name=$2
    local validator=${3:-""}
    local required=${4:-""}
    local value=""
    local valid=false
    
    while ! $valid; do
        read -p "$prompt" value
        
        # Sanitize input to prevent command injection
        value=$(echo "$value" | tr -cd '[:print:]')
        
        # Check for empty input
        if [[ -z "$value" && "$required" == "required" ]]; then
            echo -e "${RED}Error: Input cannot be empty${NC}"
            continue
        elif [[ -z "$value" && "$required" != "required" ]]; then
            valid=true
            break
        fi
        
        # Validate input if validator specified
        if [[ -n "$validator" ]]; then
            if $validator "$value"; then
                valid=true
            else
                continue
            fi
        else
            valid=true
        fi
    done
    
    # Use eval to assign to the variable name
    eval "$var_name='$value'"
}

# Read secure input (hidden)
read_secure_input() {
    local prompt=$1
    local var_name=$2
    local value=""
    
    read -sp "$prompt" value
    echo
    
    # Use eval to assign to the variable name
    eval "$var_name='$value'"
}

# Select from multiple options
select_option() {
    local prompt=$1
    local var_name=$2
    local options=("${@:3}")
    local selected=""
    
    echo -e "$prompt"
    
    # Display options
    for i in "${!options[@]}"; do
        echo -e "  $((i+1)). ${options[$i]}"
    done
    
    # Read selection
    read_input "Enter selection (1-${#options[@]}): " selection validate_number
    
    # Validate selection
    if [[ "$selection" -ge 1 && "$selection" -le "${#options[@]}" ]]; then
        selected="${options[$((selection-1))]}"
    else
        echo -e "${RED}Invalid selection${NC}"
        return 1
    fi
    
    # Assign to variable
    eval "$var_name='$selected'"
}

# Select from a file list
select_file() {
    local prompt=$1
    local var_name=$2
    local dir=$3
    local pattern=$4
    local files=()
    
    # Get list of files
    if [[ -n "$pattern" ]]; then
        mapfile -t files < <(find "$dir" -type f -name "$pattern" -exec basename {} \; | sort)
    else
        mapfile -t files < <(find "$dir" -type f -exec basename {} \; | sort)
    fi
    
    # Check if files exist
    if [[ ${#files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No files found${NC}"
        eval "$var_name=''"
        return 0
    fi
    
    # Add "Cancel" option
    files+=("Cancel")
    
    # Select file
    select_option "$prompt" selected "${files[@]}"
    
    # Handle cancel selection
    if [[ "$selected" == "Cancel" ]]; then
        eval "$var_name=''"
        return 0
    fi
    
    # Assign full path to variable
    eval "$var_name='$dir/$selected'"
}

# Confirmation prompt
confirm_action() {
    local prompt=$1
    local result_var=$2
    local response=""
    
    read -p "$prompt [y/N]: " response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        eval "$result_var=true"
    else
        eval "$result_var=false"
    fi
}

# =====================================
# Validation Functions
# =====================================

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