# Network
*Firefly server network configuration*

Network configuration for making the Firefly server accessible from the internet.

## Network Topology

```
Internet (185.96.221.52)
    ↓
Router (ALHN-FDCA-5)
    ↓ Port Forwarding (8080 → 192.168.1.76:8080)
Local Network (192.168.1.0/24)
    ↓
Mac mini Server (192.168.1.76:8080)
```

## Configuration

- **Public IP**: 185.96.221.52
- **Local Network**: 192.168.1.0/24 (WiFi: ALHN-FDCA-5)
- **Server Local IP**: 192.168.1.76 (static/DHCP reserved)
- **Server Port**: 8080
- **Port Forwarding**: 8080 (external) → 192.168.1.76:8080 (internal)
- **Protocol**: HTTP (no TLS currently)

## Setup Details

The router has been configured to:
1. Forward port 8080 to the Mac mini at 192.168.1.76
2. Assign static IP 192.168.1.76 to the Mac mini (via DHCP reservation)

The macOS firewall allows incoming connections on port 8080 for Python.

See `miso/platforms/network.md` for detailed networking setup instructions.

## Testing Access

### From Local Network
```bash
curl http://192.168.1.76:8080/api/ping
```

### From Internet
```bash
curl http://185.96.221.52:8080/api/ping
```

Expected response:
```json
{
  "message": "Firefly server is alive!",
  "status": "ok"
}
```

## Status

- ✅ Port forwarding: Configured
- ✅ Static local IP: 192.168.1.76
- ✅ macOS firewall: Allowing connections
- ✅ Server binding: 0.0.0.0:8080 (all interfaces)
- ✅ NAT loopback: Supported (can use public IP from local network)
- ❌ DDNS: Not configured (using direct IP)
- ❌ HTTPS: Not configured (using HTTP)

This setup is suitable for development and testing on a home network.
