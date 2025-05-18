#!/bin/bash

# VPN control module for OSINT Command Center

# Function to enable VPN connection
enable_vpn() {
    section_header "Enable VPN"
    
    echo -e "${YELLOW}Connecting to VPN...${NC}"
    sudo vpn on
    
    # Check if connection was successful
    if sudo vpn status | grep -q "VPN is active"; then
        status_message success "VPN connection established"
        echo
        
        # Display connection info
        echo -e "${BLUE}Connection Information:${NC}"
        sudo vpn status
    else
        status_message error "Failed to establish VPN connection"
        echo
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo -e "- Check if WireGuard is properly installed"
        echo -e "- Verify your VPN configuration"
        echo -e "- Check your internet connection"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Function to disable VPN
disable_vpn() {
    section_header "Disable VPN"
    
    echo -e "${YELLOW}Disconnecting from VPN...${NC}"
    sudo vpn off
    
    # Check if disconnection was successful
    if ! sudo vpn status | grep -q "VPN is active"; then
        status_message success "VPN disconnected successfully"
    else
        status_message error "Failed to disconnect VPN"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Function to check VPN status
check_vpn_status() {
    section_header "VPN Status"
    
    echo -e "${YELLOW}Checking VPN status...${NC}"
    
    # Check if VPN is active
    if sudo vpn status | grep -q "VPN is active"; then
        status_message success "VPN is active"
        echo
        
        # Display connection info
        echo -e "${BLUE}Connection Information:${NC}"
        sudo vpn status
    else
        status_message warning "VPN is not active"
        echo
        echo -e "${YELLOW}Your traffic is not being routed through a VPN${NC}"
    fi
    
    # Check external IP
    echo
    echo -e "${YELLOW}External IP address:${NC}"
    curl -s https://ipinfo.io/ip
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Function to enable Tor routing
enable_tor() {
    section_header "Enable Tor Routing"
    
    echo -e "${YELLOW}Setting up Tor routing...${NC}"
    sudo tor-control on
    
    # Check if Tor routing was enabled successfully
    if sudo tor-control status | grep -q "connected through Tor"; then
        status_message success "Tor routing enabled successfully"
        echo
        echo -e "${BLUE}Your traffic is now being routed through Tor${NC}"
        echo -e "${YELLOW}Note: This will significantly slow down your connection${NC}"
    else
        status_message error "Failed to enable Tor routing"
        echo
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo -e "- Check if Tor is properly installed"
        echo -e "- Verify your Tor configuration"
        echo -e "- Check your internet connection"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Function to disable Tor routing
disable_tor() {
    section_header "Disable Tor Routing"
    
    echo -e "${YELLOW}Disabling Tor routing...${NC}"
    sudo tor-control off
    
    # Check if Tor routing was disabled successfully
    if ! sudo tor-control status | grep -q "connected through Tor"; then
        status_message success "Tor routing disabled successfully"
        echo
        echo -e "${BLUE}Your traffic is now using normal routing${NC}"
    else
        status_message error "Failed to disable Tor routing"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Function to check Tor status
check_tor_status() {
    section_header "Tor Status"
    
    echo -e "${YELLOW}Checking Tor status...${NC}"
    
    # Check if Tor is active
    if systemctl is-active tor >/dev/null 2>&1; then
        echo -e "${GREEN}Tor service is running${NC}"
    else
        echo -e "${RED}Tor service is not running${NC}"
    fi
    
    # Check if transparent routing is enabled
    if sudo tor-control status | grep -q "Transparent routing is enabled"; then
        echo -e "${GREEN}Transparent routing is enabled${NC}"
    else
        echo -e "${RED}Transparent routing is not enabled${NC}"
    fi
    
    # Check if traffic is going through Tor
    if sudo tor-control status | grep -q "connected through Tor"; then
        status_message success "You are connected through Tor"
    else
        status_message warning "You are NOT connected through Tor"
    fi
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Function to configure DNS privacy
configure_dns_privacy() {
    section_header "DNS Privacy Configuration"
    
    echo -e "${BLUE}Current DNS Configuration:${NC}"
    
    # Show current DNS servers
    if [ -f /etc/resolv.conf ]; then
        echo -e "${YELLOW}Current DNS servers:${NC}"
        grep "nameserver" /etc/resolv.conf
    fi
    
    echo
    echo -e "${BLUE}Available DNS Privacy Options:${NC}"
    echo -e "1. Cloudflare Privacy DNS (1.1.1.1)"
    echo -e "2. Quad9 Secure DNS (9.9.9.9)"
    echo -e "3. OpenDNS (208.67.222.222)"
    echo -e "4. Reset to default"
    echo -e "5. Back"
    echo
    
    read_input "Select option: " option validate_number
    
    case $option in
        1)
            echo -e "${YELLOW}Setting DNS to Cloudflare Privacy DNS...${NC}"
            sudo sh -c 'echo "nameserver 1.1.1.1\nnameserver 1.0.0.1" > /etc/resolv.conf'
            status_message success "DNS set to Cloudflare Privacy DNS"
            ;;
        2)
            echo -e "${YELLOW}Setting DNS to Quad9 Secure DNS...${NC}"
            sudo sh -c 'echo "nameserver 9.9.9.9\nnameserver 149.112.112.112" > /etc/resolv.conf'
            status_message success "DNS set to Quad9 Secure DNS"
            ;;
        3)
            echo -e "${YELLOW}Setting DNS to OpenDNS...${NC}"
            sudo sh -c 'echo "nameserver 208.67.222.222\nnameserver 208.67.220.220" > /etc/resolv.conf'
            status_message success "DNS set to OpenDNS"
            ;;
        4)
            echo -e "${YELLOW}Resetting DNS to default...${NC}"
            sudo resolvconf -u
            status_message success "DNS reset to default"
            ;;
        5)
            return
            ;;
        *)
            status_message error "Invalid option"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..." dummy
}

# Security and privacy menu
security_privacy_menu() {
    display_header
    echo -e "${BLUE}[🔒] SECURITY & PRIVACY${NC}"
    echo -e "1. Enable VPN"
    echo -e "2. Disable VPN"
    echo -e "3. Check VPN Status"
    echo -e "4. Enable Tor Routing"
    echo -e "5. Disable Tor Routing"
    echo -e "6. Check Tor Status"
    echo -e "7. Configure DNS Privacy"
    echo -e "8. Network Interface Control"
    echo -e "9. Back to Main Menu"
    echo -e "0. Exit"
    echo
    
    read_input "Select option: " option validate_number
    
    case $option in
        1) enable_vpn ;;
        2) disable_vpn ;;
        3) check_vpn_status ;;
        4) enable_tor ;;
        5) disable_tor ;;
        6) check_tor_status ;;
        7) configure_dns_privacy ;;
        8) network_controls_menu ;;
        9) return ;;
        0) exit 0 ;;
        *) security_privacy_menu ;;
    esac
    
    # Return to security/privacy menu after function completes
    security_privacy_menu
}

# Network controls menu
network_controls_menu() {
    display_header
    echo -e "${BLUE}[🔌] NETWORK INTERFACE CONTROL${NC}"
    echo -e "1. Show Available Interfaces"
    echo -e "2. Show Current Routing"
    echo -e "3. Route Through Specific Interface"
    echo -e "4. Setup Phone Tethering"
    echo -e "5. Reset to Default Routing"
    echo -e "9. Back to Security Menu"
    echo -e "0. Exit"
    echo
    
    read_input "Select option: " option validate_number
    
    case $option in
        1)
            section_header "Available Network Interfaces"
            sudo osint-network list
            echo
            read -p "Press Enter to continue..." dummy
            ;;
        2)
            section_header "Current Routing Configuration"
            sudo osint-network status
            echo
            read -p "Press Enter to continue..." dummy
            ;;
        3)
            section_header "Route Through Specific Interface"
            
            # List available interfaces
            echo -e "${YELLOW}Available interfaces:${NC}"
            sudo osint-network list | grep -E "^[a-zA-Z0-9]" | awk '{print $1}'
            echo
            
            read_input "Enter interface name: " iface validate_interface
            
            if [[ -n "$iface" ]]; then
                echo -e "${YELLOW}Routing through $iface...${NC}"
                sudo osint-network use "$iface" "$(whoami)"
                status_message success "Traffic now routed through $iface"
            fi
            echo
            read -p "Press Enter to continue..." dummy
            ;;
        4)
            section_header "Setup Phone Tethering"
            echo -e "${YELLOW}Setting up phone tethering...${NC}"
            
            echo -e "${BLUE}Steps to set up phone tethering:${NC}"
            echo -e "1. Connect your phone via USB"
            echo -e "2. Enable USB tethering on your phone"
            echo -e "3. The system will automatically detect the phone"
            echo
            
            read -p "Have you connected your phone and enabled USB tethering? (y/n): " confirm
            
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                sudo osint-network phone
                status_message info "Check the output above for status"
            else
                status_message warning "Phone tethering setup canceled"
            fi
            echo
            read -p "Press Enter to continue..." dummy
            ;;
        5)
            section_header "Reset to Default Routing"
            echo -e "${YELLOW}Resetting routing to default...${NC}"
            sudo osint-network reset
            status_message success "Routing reset to default"
            echo
            read -p "Press Enter to continue..." dummy
            ;;
        9)
            return
            ;;
        0)
            exit 0
            ;;
        *)
            network_controls_menu
            ;;
    esac
    
    # Return to network menu after function completes
    network_controls_menu
}