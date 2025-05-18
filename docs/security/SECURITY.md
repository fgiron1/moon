# OSINT Command Center Security Guide

This guide provides security best practices and considerations for using the OSINT Command Center.

## Overview

OSINT research can expose you to various security risks. This guide outlines the security features of the OSINT Command Center and provides recommendations for secure operation.

## Security Features

### Network Security

#### VPN Integration

The OSINT Command Center includes built-in VPN support:

```bash
# Enable VPN
vpn on

# Check VPN status
vpn status

# Disable VPN
vpn off
```

#### Tor Routing

For enhanced anonymity, you can route traffic through the Tor network:

```bash
# Enable Tor routing
tor-control on

# Check Tor status
tor-control status

# Disable Tor routing
tor-control off
```

#### Network Interface Control

The system allows routing traffic through specific interfaces, including tethered mobile phones:

```bash
# List available interfaces
osint-network list

# Route traffic through a specific interface
osint-network use wlan0 campo

# Route traffic through a tethered phone
osint-network phone

# Reset to default routing
osint-network reset
```

#### DNS Privacy

Configure secure DNS servers to prevent DNS leaks:

```bash
# From the Security & Privacy menu
7. Configure DNS Privacy
```

### System Security

#### SSH Hardening

The system implements SSH hardening measures:

- ED25519 key-based authentication
- Limited login attempts
- Fail2ban integration for brute force protection
- Separated user accounts (root vs campo)

#### Container Isolation

OSINT tools run in isolated containers to prevent cross-contamination and contain potential compromises.

#### Secure Data Handling

The system includes tools for secure data management:

```bash
# Securely wipe specific data
# From System Controls > Data Management > Secure Data Wipe
```

#### Automatic Security Updates

The system is configured to automatically apply security updates.

## Operational Security Recommendations

### Identity Separation

1. **Never use personal accounts or identifiers** for OSINT research
2. **Create dedicated research personas** for different types of investigations
3. **Route different investigations through different exit points** (VPN servers, Tor circuits)

### Network Security

1. **Always enable VPN or Tor** before starting research
2. **Verify your public IP** before beginning sensitive work
3. **Use phone tethering** for additional network separation
4. **Test for leaks** regularly using the leak test tool

```bash
# Run leak test
osint-network leaktest
```

### Data Security

1. **Use compartmentalized targets** to separate different investigations
2. **Regularly wipe sensitive data** when no longer needed
3. **Export data securely** using encrypted archives
4. **Never open unknown or untrusted files** directly on the system

### Physical Security

1. **Keep your SSH key secure** and protected with a strong passphrase
2. **Use a screen privacy filter** when working in public
3. **Be aware of shoulder surfing** in public spaces
4. **Lock your device** when stepping away

## Security Incident Response

In case of a suspected security incident:

1. **Disconnect from the network** immediately
2. **Document the incident** with screenshots and notes
3. **Secure wipe any compromised data**
4. **Rebuild the server** from scratch if necessary

## Regular Security Checks

Perform these security checks regularly:

1. **Run the security audit tool**:
   ```bash
   sudo /opt/osint/scripts/security_audit.sh
   ```

2. **Check for suspicious processes**:
   ```bash
   ps aux | grep -v "^root\|^campo\|^nobody"
   ```

3. **Review authentication logs**:
   ```bash
   sudo grep "authentication failure\|Failed password" /var/log/auth.log
   ```

4. **Verify container integrity**:
   ```bash
   sudo /opt/osint/core/containers/manager.sh list
   ```

## Additional Security Resources

For more detailed security guidance, refer to:

- [Personal Security Tips](../../core/security/personal_security_tips.md)
- [Secure Communications Guide](../../tools/data-correlation/python/templates/secure_comms_guide.md)

## Legal and Ethical Considerations

- Always respect applicable laws and regulations
- Do not use these tools for unauthorized access to systems
- Respect privacy and personal boundaries
- Document your actions for accountability

---

© 2025 OSINT Command Center Project