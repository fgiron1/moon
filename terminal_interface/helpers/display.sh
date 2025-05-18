#!/bin/bash

# Display functions for OSINT Command Center

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

# Get VPN status for display
get_vpn_status() {
    if vpn status | grep -q "VPN is active"; then
        echo -e "${GREEN}●${NC} Connected"
    else
        echo -e "${RED}●${NC} Disconnected"
    fi
}

# Get Tor status for display
get_tor_status() {
    if systemctl is-active tor >/dev/null && tor-control status | grep -q "Transparent routing is enabled"; then
        echo -e "${GREEN}●${NC} Active"
    else
        echo -e "${RED}●${NC} Inactive"
    fi
}