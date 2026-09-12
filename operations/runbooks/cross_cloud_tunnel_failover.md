# Operational Runbook: Cross-Cloud Multi-Region IPsec Tunnel Failover

**Severity:** P1 / Inter-Cloud Network Degraded  
**Target Systems:** AWS Transit Gateway VPN, Azure Virtual WAN, BGP Peering

## Diagnostic Workflow

### 1. Verify BGP Session Status on AWS Side
```bash
aws ec2 describe-vpn-connections \
  --region us-east-1 \
  --query 'VpnConnections[*].VgwTelemetry'
```
Expected status for active tunnels: `Status: UP`, `AcceptedRouteCount > 0`.

### 2. Verify Azure Virtual Network Gateway Connections
```bash
az network vpn-connection show \
  --name aws-azure-interconnect \
  --resource-group mosaic-network-rg \
  --query '{Status:connectionStatus,EgressBytes:egressBytesTransferred}'
```

### 3. Step-by-Step Remediation for Stalled BGP Route Flapping
1. Reset IPsec Phase 2 Security Association on AWS:
   ```bash
   aws ec2 reset-vpn-connection-telemetry --vpn-connection-id vpn-0123456789abcdef0
   ```
2. Trigger automated secondary Route53 / Azure Private DNS failover:
   ```bash
   python -m src.network_failover --force-standby-route
   ```
