# Configuration Management Guide

## Overview

This document explains how configuration is managed in the OSINT Command Center project, including local development and deployment configurations.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration Layers](#configuration-layers)
3. [Development Workflow](#development-workflow)
4. [Deployment Workflow](#deployment-workflow)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

## Quick Start

1. **Copy the template**:
   ```bash
   cp .env.template .env
   ```

2. **Edit your configuration**:
   ```bash
   nano .env  # or use your preferred editor
   ```

3. **Update Ansible variables**:
   ```bash
   ./deploy/scripts/update_ansible_vars.sh
   ```

## Configuration Layers

### 1. Environment Configuration (`.env`)
- Primary configuration file
- Used for both development and deployment
- Contains sensitive data (never commit to version control)
- Variables are in UPPERCASE (e.g., `DATA_DIR`)

### 2. Ansible Variables
- Auto-generated from `.env`
- Stored in `deploy/ansible/group_vars/all/env_vars.yml`
- Variables are in lowercase (e.g., `data_dir`)
- Used during deployment

## Development Workflow

1. **Local Development**:
   - Use `.env` for local environment variables
   - Access variables in Python: `os.getenv('VARIABLE_NAME')`
   - Access in shell scripts: `$VARIABLE_NAME`

2. **Adding New Variables**:
   1. Add to `.env.template` with a default value
   2. Document the variable in this guide
   3. Run `update_ansible_vars.sh`

## Deployment Workflow

1. **Before Deployment**:
   - Update `.env` with production values
   - Run `./deploy/scripts/update_ansible_vars.sh`
   - Verify changes in `deploy/ansible/group_vars/all/env_vars.yml`

2. **During Deployment**:
   - Ansible playbooks use variables from `env_vars.yml`
   - Example usage in playbooks:
     ```yaml
     - name: Create data directory
       file:
         path: "{{ data_dir }}"
         state: directory
         mode: '0755'
     ```

## Best Practices

1. **Security**:
   - Never commit `.env` to version control
   - Use strong, unique values for sensitive data
   - Rotate credentials regularly

2. **Maintainability**:
   - Document all variables in `.env.template`
   - Group related variables together
   - Use comments to explain non-obvious settings

3. **Version Control**:
   - Always commit changes to `.env.template`
   - Never commit `env_vars.yml` (add to `.gitignore`)

## Troubleshooting

### Variables not updating in Ansible
1. Did you run `update_ansible_vars.sh` after changing `.env`?
2. Check for typos in variable names
3. Verify file permissions on `env_vars.yml`

### Variable not found in Ansible
1. Ensure the variable is defined in `.env`
2. Check the case (Ansible variables are lowercase)
3. Verify the variable is not being overridden elsewhere

### Deployment issues
1. Check Ansible logs for specific errors
2. Verify all required variables are set in `.env`
3. Ensure the target server has proper permissions to access required resources
