#!/bin/bash

# Script to set up network interface control for mobile devices
# Usage: network_control.sh [interface] [action]

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: This script must be run as root${NC}"
  exit 1
fi

# Configuration
OSINT_USER=${3:-"campo"} # Default to campo user if not specified
ROUTING_TABLE="osint"
MARK_VALUE="1"

# Function to list available interfaces
list_interfaces() {
  echo -e "${BLUE}Available network interfaces:${NC}"
  
  # Get all interfaces excluding loopback
  interfaces=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}')
  
  for iface in $interfaces; do
    # Get IP address
    ip_addr=$(ip -o -4 addr show dev $iface 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    if [ -z "$ip_addr" ]; then
      ip_addr="No IPv4 address"
    fi
    
    # Determine interface type
    if [[ $iface == usb* ]] || [[ $iface == enp0s*u* ]]; then
      echo -e "${GREEN}$iface${NC} - USB/Mobile - $ip_addr"
    elif [[ $iface == wlan* ]]; then
      echo -e "${GREEN}$iface${NC} - Wireless - $ip_addr"
    elif [[ $iface == tun* ]] || [[ $iface == wg* ]]; then
      echo -e "${GREEN}$iface${NC} - VPN Tunnel - $ip_addr"
    else
      echo -e "${GREEN}$iface${NC} - Wired - $ip_addr"
    fi
  done
}

# Function to detect connected phones
detect_phones() {
  echo -e "${BLUE}Detecting connected phones...${NC}"
  
  # Look for USB network interfaces (likely from phone tethering)
  usb_interfaces=$(ip -o link show | grep -E "usb|enp0s.*u" | awk -F': ' '{print $2}')
  
  if [ -z "$usb_interfaces" ]; then
    echo -e "${YELLOW}No phone detected. Please ensure:${NC}"
    echo -e "1. Phone is connected via USB"
    echo -e "2. USB tethering is enabled on your phone"
    echo -e "3. Phone is recognized by the system"
    
    # Show connected USB devices for debugging
    echo -e "\n${BLUE}Connected USB devices:${NC}"
    lsusb | grep -E "Phone|Android|Apple|Samsung|Google|LG|Motorola|Nokia|Sony|Xiaomi|OPPO|Vivo|Huawei|OnePlus" || echo "No phones detected via USB"
    
    return 1
  fi
  
  echo -e "${GREEN}Found potential phone interfaces:${NC}"
  for iface in $usb_interfaces; do
    ip_addr=$(ip -o -4 addr show dev $iface 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    if [ -z "$ip_addr" ]; then
      echo -e "$iface - No IP address assigned yet"
    else
      echo -e "$iface - IP address: $ip_addr"
    fi
  done
  
  return 0
}

# Function to set up phone tethering
setup_phone_tethering() {
  # Detect phones
  detect_phones
  
  if [ $? -ne 0 ]; then
    return 1
  fi
  
  # Get available USB interfaces
  usb_interfaces=$(ip -o link show | grep -E "usb|enp0s.*u" | awk -F': ' '{print $2}')
  
  # If multiple interfaces found, let user select one
  if [ $(echo "$usb_interfaces" | wc -w) -gt 1 ]; then
    echo -e "${YELLOW}Multiple USB interfaces found. Please select one:${NC}"
    select iface in $usb_interfaces; do
      if [ -n "$iface" ]; then
        selected_iface=$iface
        break
      fi
    done
  else
    selected_iface=$usb_interfaces
  fi
  
  # Check if interface has IP address
  ip_addr=$(ip -o -4 addr show dev $selected_iface 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
  if [ -z "$ip_addr" ]; then
    echo -e "${YELLOW}Interface $selected_iface has no IP address. Attempting to get one via DHCP...${NC}"
    dhclient $selected_iface
    
    # Check again for IP
    ip_addr=$(ip -o -4 addr show dev $selected_iface 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    if [ -z "$ip_addr" ]; then
      echo -e "${RED}Failed to get an IP address for interface $selected_iface${NC}"
      return 1
    fi
  fi
  
  echo -e "${GREEN}Successfully connected to phone interface $selected_iface with IP $ip_addr${NC}"
  
  # Set up routing through this interface
  setup_routing $selected_iface
  
  return 0
}

# Function to set up routing through specific interface
setup_routing() {
  local interface=$1
  
  # Check if interface exists
  if ! ip link show dev $interface &>/dev/null; then
    echo -e "${RED}Error: Interface $interface does not exist${NC}"
    return 1
  fi
  
  # Check if interface has an IP address
  ip_addr=$(ip -o -4 addr show dev $interface 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
  if [ -z "$ip_addr" ]; then
    echo -e "${RED}Error: Interface $interface has no IP address${NC}"
    return 1
  fi
  
  # Get gateway for interface
  gateway=$(ip route | grep $interface | grep default | awk '{print $3}')
  
  # If no gateway found, try to determine one
  if [ -z "$gateway" ]; then
    # For USB tethering, often the first address in the network is the gateway
    gateway=$(echo $ip_addr | cut -d. -f1-3).1
    echo -e "${YELLOW}No gateway found for interface $interface. Using $gateway as assumed gateway.${NC}"
  fi
  
  echo -e "${BLUE}Setting up routing through interface $interface ($ip_addr)...${NC}"
  
  # Ensure IP forwarding is enabled
  echo 1 > /proc/sys/net/ipv4/ip_forward
  
  # Create routing table if it doesn't exist
  if ! grep -q "$ROUTING_TABLE" /etc/iproute2/rt_tables; then
    echo "200 $ROUTING_TABLE" >> /etc/iproute2/rt_tables
  fi
  
  # Flush existing rules and routes
  ip rule del fwmark $MARK_VALUE lookup $ROUTING_TABLE 2>/dev/null
  ip route flush table $ROUTING_TABLE 2>/dev/null
  
  # Set up new route
  ip route add default via $gateway dev $interface table $ROUTING_TABLE
  ip rule add fwmark $MARK_VALUE lookup $ROUTING_TABLE
  
  # Set up iptables for user
  iptables -t mangle -D OUTPUT -m owner --uid-owner $OSINT_USER -j MARK --set-mark $MARK_VALUE 2>/dev/null
  iptables -t mangle -A OUTPUT -m owner --uid-owner $OSINT_USER -j MARK --set-mark $MARK_VALUE
  
  echo -e "${GREEN}Routing for user '$OSINT_USER' configured through $interface${NC}"
  echo -e "${GREEN}All traffic from user '$OSINT_USER' will now go through $interface${NC}"
  
  return 0
}

# Function to reset routing to default
reset_routing() {
  echo -e "${BLUE}Resetting routing to default...${NC}"
  
  # Remove routing rules
  ip rule del fwmark $MARK_VALUE lookup $ROUTING_TABLE 2>/dev/null
  ip route flush table $ROUTING_TABLE 2>/dev/null
  
  # Remove iptables rules
  iptables -t mangle -D OUTPUT -m owner --uid-owner $OSINT_USER -j MARK --set-mark $MARK_VALUE 2>/dev/null
  
  echo -e "${GREEN}Routing reset to default${NC}"
  
  return 0
}

# Function to display current routing
show_routing() {
  echo -e "${BLUE}Current routing configuration:${NC}"
  
  # Show IP forwarding status
  echo -e "${YELLOW}IP Forwarding status:${NC}"
  cat /proc/sys/net/ipv4/ip_forward
  echo
  
  # Show routing rules
  echo -e "${YELLOW}Routing rules:${NC}"
  ip rule show
  echo
  
  # Show OSINT routing table
  echo -e "${YELLOW}OSINT routing table:${NC}"
  ip route show table $ROUTING_TABLE 2>/dev/null || echo "No routes in OSINT table"
  echo
  
  # Show iptables rules
  echo -e "${YELLOW}Marking rules for OSINT user:${NC}"
  iptables -t mangle -L OUTPUT -v | grep $OSINT_USER || echo "No marking rules for OSINT user"
  echo
  
  # Show current default route
  echo -e "${YELLOW}Current default route:${NC}"
  ip route show | grep default
  
  return 0
}

# Function to show usage
show_usage() {
  echo -e "${BLUE}OSINT Network Control Script${NC}"
  echo -e "Usage: $0 [command] [interface] [user]"
  echo -e ""
  echo -e "Commands:"
  echo -e "  ${GREEN}list${NC}      - List available network interfaces"
  echo -e "  ${GREEN}status${NC}    - Show current routing configuration"
  echo -e "  ${GREEN}phone${NC}     - Set up phone tethering"
  echo -e "  ${GREEN}route${NC}     - Route through specific interface"
  echo -e "  ${GREEN}reset${NC}     - Reset routing to default"
  echo -e "  ${GREEN}help${NC}      - Show this help"
  echo -e ""
  echo -e "Examples:"
  echo -e "  $0 list"
  echo -e "  $0 phone"
  echo -e "  $0 route wlan0 campo"
  echo -e "  $0 status"
  echo -e "  $0 reset"
  echo -e ""
}

# Main function
main() {
  command=$1
  interface=$2
  
  case "$command" in
    list)
      list_interfaces
      ;;
    status)
      show_routing
      ;;
    phone)
      setup_phone_tethering
      ;;
    route)
      if [ -z "$interface" ]; then
        echo -e "${RED}Error: Interface required for route command${NC}"
        show_usage
        exit 1
      fi
      setup_routing $interface
      ;;
    reset)
      reset_routing
      ;;
    help|--help|-h)
      show_usage
      ;;
    *)
      echo -e "${RED}Error: Unknown command '$command'${NC}"
      show_usage
      exit 1
      ;;
  esac
}

# Call main function with all arguments
main "$@"