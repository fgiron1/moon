#!/bin/bash

# Input handling functions for OSINT Command Center

# Read input with validation
read_input() {
    local prompt=$1
    local var_name=$2
    local validator=$3
    local required=$4
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