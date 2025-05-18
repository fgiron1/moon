# OSINT Command Center User Guide

This guide provides instructions for using the OSINT Command Center, a comprehensive suite of OSINT (Open Source Intelligence) tools designed for security researchers, ethical hackers, and privacy-conscious investigators.

## Accessing the System

### SSH Access

You can access the OSINT Command Center using SSH:

```bash
# Full system access (root user)
ssh -i ~/.ssh/id_ed25519 root@SERVER_IP

# Mobile-friendly interface (campo user)
ssh -i ~/.ssh/id_ed25519 campo@SERVER_IP
```

### Terminal Interface

When connecting as the `campo` user, you'll automatically be presented with the mobile-friendly terminal interface.

## Main Menu Navigation

The main menu provides access to all OSINT tools and system features:

```
======================================
       OSINT COMMAND CENTER
======================================
VPN: INACTIVE | Containers: 5 | 2025-05-18 15:30
--------------------------------------

1. [🌐] Domain Intelligence
2. [🔍] Network Scanning
3. [👤] Identity Research
4. [🕸️] Web Analysis
5. [🔒] Security & Privacy
6. [⚙️] System Controls
7. [📊] Data Correlation
0. [✖] Exit

Select option:
```

Navigate by entering the number corresponding to the desired option.

## Key Features

### 1. Domain Intelligence

The Domain Intelligence module allows you to gather information about domains and subdomains:

- **Domain Reconnaissance**: Collect passive information about a domain
- **Subdomain Enumeration**: Discover subdomains using passive or active methods
- **DNS Analysis**: Analyze DNS records for a domain

Example usage:

```
# From the main menu, select option 1
1. [🌐] Domain Intelligence

# Then select the desired tool
1. Domain Reconnaissance

# Enter the target domain
Enter domain to scan: example.com
```

### 2. Network Scanning

The Network Scanning module provides tools for scanning networks and hosts:

- **Port Scan**: Scan a single host for open ports
- **Service Detection**: Identify services running on open ports
- **Network Reconnaissance**: Discover hosts on a network
- **Vulnerability Scanning**: Check for known vulnerabilities

Example usage:

```
# From the main menu, select option 2
2. [🔍] Network Scanning

# Then select the desired tool
1. Port Scan (Single Host)

# Enter the target IP or domain
Enter target IP or domain: 192.168.1.1
```

### 3. Identity Research

The Identity Research module helps you investigate usernames, email addresses, and phone numbers:

- **Username Search**: Search for usernames across multiple platforms
- **Email Investigation**: Find accounts associated with an email address
- **Phone Number Analysis**: Analyze phone numbers
- **Social Media Discovery**: Discover social media profiles

Example usage:

```
# From the main menu, select option 3
3. [👤] Identity Research

# Then select the desired tool
1. Username Search

# Enter the target username
Enter username to search: johndoe
```

### 4. Web Analysis

The Web Analysis module provides tools for analyzing websites:

- **Website Security Scan**: Scan for security vulnerabilities
- **Technology Detection**: Identify technologies used by a website
- **Content Discovery**: Discover hidden directories and files

Example usage:

```
# From the main menu, select option 4
4. [🕸️] Web Analysis

# Then select the desired tool
1. Website Security Scan

# Enter the target URL
Enter website URL: https://example.com
```

### 5. Security & Privacy

The Security & Privacy module helps you secure your OSINT operations:

- **VPN Controls**: Enable/disable VPN connection
- **Tor Routing**: Route traffic through the Tor network
- **DNS Privacy**: Configure secure DNS settings
- **Network Interface Control**: Route traffic through specific interfaces

Example usage:

```
# From the main menu, select option 5
5. [🔒] Security & Privacy

# Then select the desired tool
1. Enable VPN
```

### 6. System Controls

The System Controls module provides access to system management features:

- **Update OSINT Tools**: Update all OSINT tools
- **System Status**: Check system status
- **Data Management**: Manage data files
- **View Logs**: View system and tool logs
- **Power Management**: Restart or shut down the server

Example usage:

```
# From the main menu, select option 6
6. [⚙️] System Controls

# Then select the desired tool
2. System Status
```

### 7. Data Correlation

The Data Correlation module allows you to correlate data from different sources:

- **Process Target Data**: Process collected data for a target
- **Import to Neo4j**: Import data into the Neo4j database
- **Generate Visualization**: Create visual representations of relationships
- **Generate Report**: Create reports based on collected data
- **Export Data**: Export data in various formats

Example usage:

```
# From the main menu, select option 7
7. [📊] Data Correlation

# Then select the desired tool
1. Process Target Data

# Enter the target name
Enter target name: example.com
```

## Using Phone Tethering

The OSINT Command Center allows you to route traffic through a USB tethered phone:

1. Connect your phone via USB to the server
2. Enable USB tethering on your phone
3. In the mobile interface, go to Security & Privacy > Network controls > Set up phone tethering

## Exporting Data

Each module provides options to export data in various formats. Generally, exports are saved to the `/opt/osint/data/exports` directory.

## Security Recommendations

For optimal security during OSINT operations:

1. **Always use VPN or Tor** when conducting sensitive research
2. **Route through your phone** when additional anonymity is required
3. **Compartmentalize your research** by creating separate target directories
4. **Regularly wipe sensitive data** using the secure wipe tool
5. **Update tools regularly** to ensure you have the latest security patches
6. **Check your actual IP** before starting sensitive work

## Command Line Interface

In addition to the interactive menu, you can also use the OSINT Command Center directly from the command line:

```bash
# Run domain tools
campo domain amass -d example.com

# Run network tools
campo network nmap -p 80,443 example.com

# Run identity tools
campo identity sherlock username

# Run web tools
campo web nuclei -u https://example.com

# Run data correlation
campo data correlate example.com

# Check system status
campo system status

# Control network
campo network-control status
```

## Additional Resources

For more information, refer to the following resources:

- [Deployment Guide](../deployment/DEPLOYMENT.md)
- [Security Guide](../security/SECURITY.md)
- [Personal Security Tips](../../core/security/personal_security_tips.md)
- [Secure Communications Guide](../../tools/data-correlation/python/templates/secure_comms_guide.md)

---

© 2025 OSINT Command Center Project