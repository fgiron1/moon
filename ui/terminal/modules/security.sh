#!/bin/bash

# ui/terminal/modules/security.sh
# Security & privacy module for OSINT Command Center Terminal Interface

# =====================================
# VPN Control Functions
# =====================================

# Enable VPN connection
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
    
    # Check public IP with external service
    local ip=$(curl -s https://ipinfo.io/ip)
    echo -e "${BLUE}Current public IP:${NC} $ip"
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

# Disable VPN
disable_vpn() {
  section_header "Disable VPN"
  
  echo -e "${YELLOW}Disconnecting from VPN...${NC}"
  sudo vpn off
  
  # Check if disconnection was successful
  if ! sudo vpn status | grep -q "VPN is active"; then
    status_message success "VPN disconnected successfully"
    
    # Check public IP with external service
    local ip=$(curl -s https://ipinfo.io/ip)
    echo -e "${BLUE}Current public IP:${NC} $ip"
  else
    status_message error "Failed to disconnect VPN"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Check VPN status
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
  
  # Check for IP leaks
  echo -e "${YELLOW}Checking for IP leaks...${NC}"
  
  # Try to contact different services to check for leaks
  ipv4_leak=$(curl -s -4 https://ipinfo.io/ip 2>/dev/null)
  ipv6_leak=$(curl -s -6 https://ipinfo.io/ip 2>/dev/null)
  
  if [ -n "$ipv6_leak" ]; then
    status_message error "Potential IPv6 leak detected: $ipv6_leak"
    echo -e "${YELLOW}Consider disabling IPv6 to prevent leaks${NC}"
  else
    status_message success "No IPv6 leaks detected"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# =====================================
# Tor Routing Functions
# =====================================

# Enable Tor routing
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
    
    # Check Tor exit node
    echo -e "${BLUE}Current Tor exit node:${NC}"
    curl -s https://check.torproject.org/api/ip
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

# Disable Tor routing
disable_tor() {
  section_header "Disable Tor Routing"
  
  echo -e "${YELLOW}Disabling Tor routing...${NC}"
  sudo tor-control off
  
  # Check if Tor routing was disabled successfully
  if ! sudo tor-control status | grep -q "connected through Tor"; then
    status_message success "Tor routing disabled successfully"
    echo
    echo -e "${BLUE}Your traffic is now using normal routing${NC}"
    
    # Check public IP
    echo -e "${BLUE}Current public IP:${NC}"
    curl -s https://ipinfo.io/ip
  else
    status_message error "Failed to disable Tor routing"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# Check Tor status
check_tor_status() {
  section_header "Tor Status"
  
  echo -e "${YELLOW}Checking Tor status...${NC}"
  
  # Check if Tor service is active
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
    
    # Check if Tor connection is working properly
    echo -e "${YELLOW}Verifying Tor connection...${NC}"
    tor_check=$(curl -s https://check.torproject.org/api/ip)
    
    if echo "$tor_check" | grep -q "IsTor\":true"; then
      status_message success "Tor connection verified"
      echo -e "${BLUE}Tor exit node:${NC} $(echo "$tor_check" | grep -o '"IP":"[^"]*"' | cut -d'"' -f4)"
    else
      status_message error "Tor connection check failed"
    fi
  else
    status_message warning "You are NOT connected through Tor"
  fi
  
  echo
  read -p "Press Enter to continue..." dummy
}

# =====================================
# DNS Privacy Functions
# =====================================

# Configure DNS privacy
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
  echo -e "4. Mullvad DNS (10.64.0.1)"
  echo -e "5. Reset to default"
  echo -e "9. Back"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1)
      echo -e "${YELLOW}Setting DNS to Cloudflare Privacy DNS...${NC}"
      sudo $NETWORK_MANAGER dns cloudflare
      status_message success "DNS set to Cloudflare Privacy DNS"
      ;;
    2)
      echo -e "${YELLOW}Setting DNS to Quad9 Secure DNS...${NC}"
      sudo $NETWORK_MANAGER dns quad9
      status_message success "DNS set to Quad9 Secure DNS"
      ;;
    3)
      echo -e "${YELLOW}Setting DNS to OpenDNS...${NC}"
      sudo $NETWORK_MANAGER dns opendns
      status_message success "DNS set to OpenDNS"
      ;;
    4)
      echo -e "${YELLOW}Setting DNS to Mullvad DNS...${NC}"
      sudo sh -c 'echo "nameserver 10.64.0.1" > /etc/resolv.conf'
      status_message success "DNS set to Mullvad DNS"
      ;;
    5)
      echo -e "${YELLOW}Resetting DNS to default...${NC}"
      sudo $NETWORK_MANAGER dns reset
      status_message success "DNS reset to default"
      ;;
    9)
      return
      ;;
    *)
      status_message error "Invalid option"
      ;;
  esac
  
  echo
  read -p "Press Enter to continue..." dummy
}

# =====================================
# Network Interface Control Functions
# =====================================

# Network controls menu
network_controls_menu() {
  section_header "Network Interface Control"
  echo -e "1. Show Available Interfaces"
  echo -e "2. Show Current Routing"
  echo -e "3. Route Through Specific Interface"
  echo -e "4. Setup Phone Tethering"
  echo -e "5. Reset to Default Routing"
  echo -e "6. Run Network Leak Test"
  echo -e "9. Back"
  echo
  
  read_input "Select option: " option validate_number
  
  case $option in
    1)
      section_header "Available Network Interfaces"
      sudo $NETWORK_MANAGER list
      echo
      read -p "Press Enter to continue..." dummy
      ;;
    2)
      section_header "Current Routing Configuration"
      sudo $NETWORK_MANAGER status
      echo
      read -p "Press Enter to continue..." dummy
      ;;
    3)
      section_header "Route Through Specific Interface"
      
      # List available interfaces
      echo -e "${YELLOW}Available interfaces:${NC}"
      interfaces=$(sudo $NETWORK_MANAGER list | grep -E "^[a-zA-Z0-9]" | awk '{print $1}')
      
      # Convert to array and display with numbers
      IFS=$'\n' read -d '' -r -a iface_array <<< "$interfaces"
      
      for i in "${!iface_array[@]}"; do
        echo -e "$((i+1)). ${iface_array[$i]}"
      done
      echo
      
      # Select interface
      read_input "Select interface (1-${#iface_array[@]}): " iface_idx validate_number
      
      if [[ "$iface_idx" -ge 1 && "$iface_idx" -le "${#iface_array[@]}" ]]; then
        local selected_iface="${iface_array[$((iface_idx-1))]}"
        
        # Get username
        read_input "Enter username to route traffic for: " username
        
        echo -e "${YELLOW}Routing through $selected_iface...${NC}"
        sudo $NETWORK_MANAGER route "$selected_iface" "$username"
        
        status_message success "Traffic now routed through $selected_iface"
      else
        status_message error "Invalid selection"
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
        sudo $NETWORK_MANAGER phone
      else
        status_message warning "Phone tethering setup canceled"
      fi
      echo
      read -p "Press Enter to continue..." dummy
      ;;
    5)
      section_header "Reset to Default Routing"
      echo -e "${YELLOW}Resetting routing to default...${NC}"
      sudo $NETWORK_MANAGER reset
      status_message success "Routing reset to default"
      echo
      read -p "Press Enter to continue..." dummy
      ;;
    6)
      section_header "Network Leak Test"
      sudo $NETWORK_MANAGER test
      echo
      read -p "Press Enter to continue..." dummy
      ;;
    9)
      return
      ;;
    *)
      status_message error "Invalid option"
      sleep 1
      network_controls_menu
      ;;
  esac
  
  # Return to network menu after function completes
  network_controls_menu
}

# =====================================
# Security & Privacy Menu
# =====================================

# Security and privacy menu
security_menu() {
  show_header
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
    9) return 0 ;;
    0) exit 0 ;;
    *) 
      status_message error "Invalid option"
      sleep 1
      ;;
  esac
  
  # Return to security menu after function completes
  security_menu
  return 0
}