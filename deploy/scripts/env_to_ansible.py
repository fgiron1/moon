#!/usr/bin/env python3
"""
Convert .env file to Ansible variables YAML

Usage:
    python env_to_ansible.py [input_file] [output_file]
    Defaults:
    - input_file: ../../.env
    - output_file: ../../deploy/ansible/group_vars/all/env_vars.yml
"""

import os
import sys
import yaml
from pathlib import Path

def load_env_file(env_path):
    """Load variables from .env file"""
    env_vars = {}
    
    try:
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith('#') or '=' not in line:
                    continue
                
                # Split on first '=' only
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip().strip('"\'')
                
                # Convert to lowercase for Ansible convention
                key = key.lower()
                env_vars[key] = value
                
    except FileNotFoundError:
        print(f"Warning: {env_path} not found")
        
    return env_vars

def write_ansible_vars(vars_dict, output_path):
    """Write variables to Ansible YAML file"""
    # Create output directory if it doesn't exist
    output_dir = os.path.dirname(output_path)
    os.makedirs(output_dir, exist_ok=True)
    
    with open(output_path, 'w') as f:
        # Add header
        f.write("# Auto-generated from .env file\n# DO NOT EDIT MANUALLY\n\n")
        
        # Write variables in YAML format
        yaml.dump(vars_dict, f, default_flow_style=False, sort_keys=True, width=1000)
    
    print(f"Wrote {len(vars_dict)} variables to {output_path}")

def main():
    # Set default paths
    project_root = Path(__file__).parent.parent.parent
    default_env = project_root / '.env'
    default_output = project_root / 'deploy' / 'ansible' / 'group_vars' / 'all' / 'env_vars.yml'
    
    # Get input and output paths from command line or use defaults
    env_path = sys.argv[1] if len(sys.argv) > 1 else str(default_env)
    output_path = sys.argv[2] if len(sys.argv) > 2 else str(default_output)
    
    # Convert and write variables
    env_vars = load_env_file(env_path)
    if env_vars:
        write_ansible_vars(env_vars, output_path)
    else:
        print("No variables found or .env file is empty")

if __name__ == "__main__":
    main()
