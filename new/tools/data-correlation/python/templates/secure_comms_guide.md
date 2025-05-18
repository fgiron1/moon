# OSINT Command Center - Personal Secure Communications Guide

This guide provides recommendations for maintaining secure communications during OSINT investigations.

## Core Principles

1. **Separation of identity**: Never use personal accounts for OSINT work
2. **End-to-end encryption**: Ensure your communications cannot be intercepted
3. **Metadata awareness**: Be conscious of metadata leakage
4. **Forward secrecy**: Even if keys are compromised, past communications remain secure
5. **Verification**: Verify recipients through secure channels

## Recommended Tools

### Secure Messaging

| Application | Strengths | Limitations | Best Use Case |
|-------------|-----------|------------|--------------|
| Signal | Strong E2E encryption, minimal metadata, disappearing messages | Requires phone number | Primary secure messaging app |
| Wire | E2E encryption, minimal personal info needed | Less widely used | Team communications |
| Keybase | E2E encryption, identity verification | Requires username | Secure file transfers |
| Session | Decentralized, no phone number needed | New platform, smaller user base | Anonymous communications |

### Secure Email

| Service | Strengths | Limitations | Best Use Case |
|---------|-----------|------------|--------------|
| ProtonMail | E2E encryption, zero-access encryption | Limited free tier | General secure email |
| Tutanota | E2E encryption, secure calendar | Limited integrations | Team communications |
| Temp Mail | Disposable addresses | No persistent identity | One-time communications |

### Secure Voice/Video

| Application | Strengths | Limitations | Best Use Case |
|-------------|-----------|------------|--------------|
| Signal | E2E encrypted calls | Requires phone number | Quick secure calls |
| Jitsi Meet | Open source, no account needed | Server dependent | Ad-hoc team meetings |
| Wickr | E2E encryption, screen sharing | Enterprise focus | Team conferences |

## Setting Up Signal as Primary Communications Tool

1. **Installation**:
   - Use a dedicated phone number (not your personal number)
   - Install on a dedicated device when possible
   
2. **Security settings**:
   - Enable registration lock
   - Set up a PIN
   - Enable disappearing messages by default
   - Verify safety numbers with contacts
   
3. **Operational practices**:
   - Clear message history regularly
   - Use disappearing messages for sensitive content
   - Verify contacts through alternative channels
   - Do not back up messages to cloud services

## Communications Security Protocols

### For Team Communications

1. **Daily Operations**:
   - Use Signal for routine communications
   - Set appropriate disappearing message timers (24h recommended)
   - Use code words for sensitive topics when appropriate
   
2. **Sensitive Operations**:
   - Use ephemeral messaging with short timers
   - Confirm receipt and instruct manual deletion
   - Consider air-gapped communication methods for critical information

### For Source Communications

1. **Initial Contact**:
   - Use anonymous platforms for first contact
   - Establish authentication protocols
   - Move to secure channels quickly
   
2. **Ongoing Communications**:
   - Use different secure channels for different sources
   - Establish emergency protocols
   - Regular security review of communications methods

## File Transfer Security

1. **Before Sending Files**:
   - Remove metadata (use the metadata removal tools in OSINT Command Center)
   - Encrypt sensitive files with strong passwords
   - Consider splitting sensitive data across multiple channels
   
2. **Receiving Files**:
   - Scan all files in an isolated environment
   - Verify checksums when possible
   - Do not open files on production systems

## Emergency Communications Procedures

1. **If device is compromised**:
   - Notify team through secondary channel
   - Initiate compromise recovery protocol
   - Do not use compromised device for further communications
   
2. **If communication platform is compromised**:
   - Switch to backup platform according to team protocol
   - Use out-of-band authentication for new platform
   - Document incident after securing communications

## Remember

- No communication system is perfectly secure
- The security of any system is limited by its weakest implementation
- Regular security audits of communications procedures are essential
- The human element is often the weakest link in secure communications