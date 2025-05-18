#!/bin/bash
# Update Ansible variables from .env file

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Run the Python script
python3 "$SCRIPT_DIR/env_to_ansible.py" "$@"

# Make the script executable
