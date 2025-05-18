# OSINT Command Center Usage Guide

## System Overview

The OSINT Command Center is a containerized platform for OSINT (Open Source Intelligence) operations, featuring:

- Secure container orchestration
- Network scanning capabilities
- Identity intelligence
- Domain analysis
- Web interface
- Data correlation engine
- Comprehensive security measures

## Container Management

### Basic Commands

```bash
# Navigate to container directory
cd core/containers

# List all containers
./manager.sh list

# Start all containers
./manager.sh start_all

# Stop all containers
./manager.sh stop_all

# Restart all containers
./manager.sh restart_all

# Backup all containers
./manager.sh backup
```

### Container-Specific Operations

```bash
# Start specific container
./manager.sh start <container_name>

# Stop specific container
./manager.sh stop <container_name>

# Execute command in container
./manager.sh exec <container_name> <command>

# Get container status
./manager.sh show <container_name>
```

## OSINT Operations

### Network Scanning

```bash
# Run network scan
./manager.sh run_tool network_scan --target <IP/Domain>

# View scan results
cat /opt/osint/data/scan_results/network_<timestamp>.json
```

### Domain Analysis

```bash
# Run domain analysis
./manager.sh run_tool domain_analysis --domain example.com

# View analysis results
cat /opt/osint/data/analysis/domain_<timestamp>.json
```

## Data Correlation

### Using the Correlator

```bash
# Process data
cd tools/data-correlation/python
python correlator.py --target <target_name>

# View correlation results
cat /opt/osint/data/correlation/<target_name>_correlation_<timestamp>.json
```

## Security Monitoring

### Security Audit

```bash
# Run security audit
/opt/osint/scripts/security_audit.sh

# View audit reports
ls /opt/osint/data/security_reports/
```

### Monitoring Status

```bash
# Check system metrics
/opt/osint/monitoring/prometheus/metrics.sh

# View alerts
/opt/osint/monitoring/alerts.sh
```

## Best Practices

1. **Regular Backups**
   - Run backups daily
   - Verify backup integrity
   - Test restore procedures

2. **Security Updates**
   - Run security audit weekly
   - Update containers monthly
   - Monitor security alerts

3. **Resource Management**
   - Monitor container resource usage
   - Adjust limits as needed
   - Clean up old data

## Troubleshooting Guide

### Common Issues

1. **Container Performance**
   - Check resource limits
   - Monitor CPU/Memory usage
   - Adjust container configuration

2. **Network Issues**
   - Verify UFW rules
   - Check VPN connection
   - Test network connectivity

3. **Data Processing**
   - Check data directory permissions
   - Verify Neo4j connection
   - Check processing logs

## Support & Maintenance

### Support Channels

- GitHub Issues: https://github.com/your-username/moon/issues
- Documentation: https://github.com/your-username/moon/docs
- Community: Coming soon

### Maintenance Tasks

1. **Weekly**
   - Run security audit
   - Check system logs
   - Verify backups

2. **Monthly**
   - Update containers
   - Review security policies
   - Check resource usage

3. **Quarterly**
   - Full system review
   - Performance optimization
   - Security assessment
