# Main menu function
main_menu() {
  clear
  echo -e "${BLUE}======================================${NC}"
  echo -e "${BLUE}     OSINT Secure Data Wipe Tool     ${NC}"
  echo -e "${BLUE}======================================${NC}"
  echo -e "${RED}WARNING: Data deletion is permanent and cannot be undone!${NC}"
  echo
  echo -e "1. Securely delete specific file/directory"
  echo -e "2. Wipe all data for a specific target"
  echo -e "3. Wipe all exported data"
  echo -e "4. Clear tool caches and temporary files"
  echo -e "5. Exit"
  echo
  
  read -p "Select an option: " choice
  
  case $choice in
    1)
      specific_wipe
      ;;
    2)
      target_wipe
      ;;
    3)
      export_wipe
      ;;
    4)
      cache_wipe
      ;;
    5)
      echo -e "${GREEN}Exiting...${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option${NC}"
      sleep 2
      main_menu
      ;;
  esac
}

# Function to wipe specific file or directory
specific_wipe() {
  clear
  echo -e "${BLUE}Secure Deletion - Specific File/Directory${NC}"
  echo -e "${RED}WARNING: This will permanently delete the specified file/directory${NC}"
  echo
  
  read -p "Enter path to file or directory: " target_path
  
  if [ ! -e "$target_path" ]; then
    echo -e "${RED}Error: Path does not exist${NC}"
    read -p "Press Enter to continue..." dummy
    main_menu
    return
  fi
  
  echo -e "${RED}You are about to permanently delete: $target_path${NC}"
  read -p "Are you sure? (Type 'YES' to confirm): " confirm
  
  if [ "$confirm" != "YES" ]; then
    echo -e "${YELLOW}Operation canceled${NC}"
    read -p "Press Enter to continue..." dummy
    main_menu
    return
  fi
  
  if [ -f "$target_path" ]; then
    securely_delete_file "$target_path"
  elif [ -d "$target_path" ]; then
    securely_delete_directory "$target_path"
  fi
  
  echo -e "${GREEN}Secure deletion completed${NC}"
  read -p "Press Enter to continue..." dummy
  main_menu
}

# Function to wipe data for a specific target
target_wipe() {
  clear
  echo -e "${BLUE}Secure Deletion - Target Data${NC}"
  echo -e "${RED}WARNING: This will permanently delete all data for a specific target${NC}"
  echo
  
  # List available targets
  echo -e "${YELLOW}Available targets:${NC}"
  targets_dir="/opt/osint/data/targets"
  
  if [ ! -d "$targets_dir" ] || [ -z "$(ls -A $targets_dir 2>/dev/null)" ]; then
    echo -e "${RED}No targets found${NC}"
    read -p "Press Enter to continue..." dummy
    main_menu
    return
  fi
  
  ls -1 "$targets_dir" | cat -n
  
  read -p "Enter target number to delete: " target_num
  
  # Validate input
  if ! [[ "$target_num" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Invalid input. Please enter a number.${NC}"
    read -p "Press Enter to continue..." dummy
    target_wipe
    return
  fi
  
  target_name=$(ls -1 "$targets_dir" | sed -n "${target_num}p")
  
  if [ -z "$target_name" ]; then
    echo -e "${RED}Invalid selection${NC}"
    read -p "Press Enter to continue..." dummy
    target_wipe
    return
  fi
  
  target_path="$targets_dir/$target_name"
  
  echo -e "${RED}You are about to permanently delete all data for target: $target_name${NC}"
  read -p "Type the target name to confirm: " confirm
  
  if [ "$confirm" != "$target_name" ]; then
    echo -e "${YELLOW}Operation canceled${NC}"
    read -p "Press Enter to continue..." dummy
    main_menu
    return
  fi
  
  echo -e "${YELLOW}Securely deleting all data for target: $target_name${NC}"
  securely_delete_directory "$target_path"
  
  # Also delete from standardized and exports directories if they exist
  if [ -d "/opt/osint/data/standardized/$target_name" ]; then
    securely_delete_directory "/opt/osint/data/standardized/$target_name"
  fi
  
  if [ -d "/opt/osint/data/exports/$target_name" ]; then
    securely_delete_directory "/opt/osint/data/exports/$target_name"
  fi
  
  # Delete from reports if exists
  if [ -d "/opt/osint/data/reports/$target_name" ]; then
    securely_delete_directory "/opt/osint/data/reports/$target_name"
  fi
  
  echo -e "${GREEN}Target data securely deleted${NC}"
  read -p "Press Enter to continue..." dummy
  main_menu
}

# Function to wipe all exported data
export_wipe() {
  clear
  echo -e "${BLUE}Secure Deletion - All Exported Data${NC}"
  echo -e "${RED}WARNING: This will permanently delete all exported data${NC}"
  echo
  
  # Check if exports directory exists
  exports_dir="/opt/osint/data/exports"
  if [ ! -d "$exports_dir" ] || [ -z "$(ls -A $exports_dir 2>/dev/null)" ]; then
    echo -e "${RED}No exports found${NC}"
    read -p "Press Enter to continue..." dummy
    main_menu
    return
  fi
  
  echo -e "${RED}You are about to permanently delete ALL exported data${NC}"
  read -p "Type 'DELETE-EXPORTS' to confirm: " confirm
  
  if [ "$confirm" != "DELETE-EXPORTS" ]; then
    echo -e "${YELLOW}Operation canceled${NC}"
    read -p "Press Enter to continue..." dummy
    main_menu
    return
  fi
  
  echo -e "${YELLOW}Securely deleting all exported data...${NC}"
  securely_delete_directory "$exports_dir"
  mkdir -p "$exports_dir"
  
  echo -e "${GREEN}All exported data securely deleted${NC}"
  read -p "Press Enter to continue..." dummy
  main_menu
}

# Function to clear tool caches and temp files
cache_wipe() {
  clear
  echo -e "${BLUE}Clearing Tool Caches and Temporary Files${NC}"
  echo
  
  # List of directories to clean
  cache_dirs=(
    "/tmp"
    "/var/tmp"
    "/var/cache/apt"
    "/opt/osint/tools/*/cache"
    "/opt/osint/tools/*/.cache"
    "$HOME/.cache"
  )
  
  for dir in "${cache_dirs[@]}"; do
    if [ -d "$dir" ]; then
      echo -e "${YELLOW}Cleaning: $dir${NC}"
      rm -rf "$dir"/*
    fi
  done
  
  # Clean browser cache if any browsers are installed
  if [ -d "$HOME/.mozilla" ]; then
    echo -e "${YELLOW}Cleaning Firefox cache...${NC}"
    find "$HOME/.mozilla" -name "Cache" -type d -exec rm -rf {} \; 2>/dev/null
  fi
  
  if [ -d "$HOME/.config/chromium" ]; then
    echo -e "${YELLOW}Cleaning Chromium cache...${NC}"
    find "$HOME/.config/chromium" -name "Cache" -type d -exec rm -rf {} \; 2>/dev/null
  fi
  
  if command -v bleachbit &> /dev/null; then
    echo -e "${YELLOW}Running BleachBit to clean system thoroughly...${NC}"
    bleachbit --clean system.tmp system.trash system.cache system.localizations system.recent_documents system.rotated_logs &>/dev/null
  fi
  
  echo -e "${GREEN}Cache cleaning completed${NC}"
  read -p "Press Enter to continue..." dummy
  main_menu
}

# Start the main menu
main_menu