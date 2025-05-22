#!/bin/bash
# core/scripts/wordlist_manager.sh

# Wordlist Manager for OSINT Command Center

WORDLIST_DIR="/opt/osint/wordlists"

# Create directory structure
create_wordlist_structure() {
  mkdir -p "$WORDLIST_DIR"/{passwords,usernames,discovery,fuzzing,custom}
  
  # Download essential wordlists
  echo "Downloading essential wordlists..."
  
  # Passwords
  wget -q https://github.com/danielmiessler/SecLists/raw/master/Passwords/Common-Credentials/10-million-password-list-top-100000.txt \
    -O "$WORDLIST_DIR/passwords/top-100k-passwords.txt"
  
  # Usernames
  wget -q https://github.com/danielmiessler/SecLists/raw/master/Usernames/top-usernames-shortlist.txt \
    -O "$WORDLIST_DIR/usernames/common-usernames.txt"
  
  # Web discovery
  wget -q https://github.com/danielmiessler/SecLists/raw/master/Discovery/Web-Content/raft-large-directories.txt \
    -O "$WORDLIST_DIR/discovery/raft-large-directories.txt"
  
  # API endpoints
  wget -q https://github.com/danielmiessler/SecLists/raw/master/Discovery/Web-Content/api/api-endpoints.txt \
    -O "$WORDLIST_DIR/discovery/api-endpoints.txt"
  
  # Fuzzing payloads
  wget -q https://github.com/danielmiessler/SecLists/raw/master/Fuzzing/SQLi/Generic-SQLi.txt \
    -O "$WORDLIST_DIR/fuzzing/sql-injection.txt"
  
  echo "Wordlists downloaded successfully"
}

# Main execution
case "$1" in
  setup)
    create_wordlist_structure
    ;;
  update)
    echo "Updating wordlists..."
    # Add update logic
    ;;
  *)
    echo "Usage: $0 {setup|update}"
    ;;
esac