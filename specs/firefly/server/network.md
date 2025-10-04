# Network Configuration
*Router and network setup for public server access*

Configuration details for making the Firefly server accessible from the internet.

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

## Current Configuration

- **Public IP**: 185.96.221.52
- **Local Network**: 192.168.1.0/24 (WiFi: ALHN-FDCA-5)
- **Server Local IP**: 192.168.1.76
- **Server Port**: 8080
- **Port Forwarding**: 8080 (external) → 192.168.1.76:8080 (internal)

## Port Forwarding Setup

Port forwarding redirects incoming traffic from the router's public IP to a specific device on the local network.

### Why Port Forwarding is Needed

- **Problem**: Devices on local network (192.168.1.x) are not directly accessible from internet
- **Solution**: Router forwards requests on public IP:8080 to local server's IP:8080
- **Result**: Internet clients can reach http://185.96.221.52:8080

### Router Configuration Steps

The exact steps vary by router, but generally:

1. **Access Router Admin Panel**:
   - Open browser to router IP (typically 192.168.1.1 or 192.168.0.1)
   - Login with admin credentials

2. **Find Port Forwarding Section**:
   - Usually under "Advanced Settings"
   - May be called "Port Forwarding", "Virtual Server", "NAT Forwarding", or "Applications"

3. **Add Port Forwarding Rule**:
   - **Service Name**: Firefly Server (descriptive name)
   - **External Port**: 8080
   - **Internal IP**: 192.168.1.76
   - **Internal Port**: 8080
   - **Protocol**: TCP (or Both TCP/UDP)
   - **Enable**: Yes/On

4. **Save and Apply**:
   - Save settings
   - Router may reboot

### Common Router Interfaces

**TP-Link**:
- Advanced → NAT Forwarding → Virtual Servers

**Netgear**:
- Advanced → Advanced Setup → Port Forwarding/Port Triggering

**Linksys**:
- Applications & Gaming → Single Port Forwarding

**ASUS**:
- WAN → Virtual Server / Port Forwarding

**Generic**:
- Look for Advanced Settings → NAT, Firewall, or Port Forwarding sections

## Static IP Assignment

For port forwarding to work reliably, the server needs a static local IP.

### Option 1: DHCP Reservation (Recommended)

Configure router to always assign same IP to Mac mini:

1. Find Mac mini's MAC address:
   ```bash
   ifconfig en0 | grep ether
   ```
   Output: `ether xx:xx:xx:xx:xx:xx`

2. In router admin panel:
   - Find DHCP Settings or Address Reservation
   - Add reservation: MAC address → 192.168.1.76
   - Save

**Benefit**: IP stays consistent even if Mac mini restarts

### Option 2: Manual Static IP

Configure Mac mini with static IP:

1. System Settings → Network
2. Select WiFi/Ethernet connection
3. Details → TCP/IP
4. Configure IPv4: Manually
5. Set:
   - IP Address: 192.168.1.76
   - Subnet Mask: 255.255.255.0
   - Router: 192.168.1.1 (your router's IP)
   - DNS: 8.8.8.8, 8.8.4.4 (Google DNS) or your ISP's DNS

**Downside**: Must configure on each network

## Testing Port Forwarding

### Test from Local Network

```bash
curl http://192.168.1.76:8080/api/ping
```

### Test from Internet

From device NOT on local network (e.g., mobile data):
```bash
curl http://185.96.221.52:8080/api/ping
```

### Port Forwarding Checklist

If external access doesn't work:

- [ ] Server running and bound to 0.0.0.0:8080
- [ ] Local access works (192.168.1.76:8080)
- [ ] Port forwarding rule created (8080 → 192.168.1.76:8080)
- [ ] Rule is enabled/active
- [ ] Mac mini has static IP (192.168.1.76)
- [ ] macOS firewall allows Python/port 8080
- [ ] ISP doesn't block incoming port 8080
- [ ] Public IP is current (check whatismyip.com)

## NAT Loopback (Hairpinning)

**Issue**: Some routers don't support accessing public IP from inside local network.

**Symptom**: 
- External devices can reach http://185.96.221.52:8080 ✓
- Local devices get connection refused when using public IP ✗

**Workaround**:
- Use local IP (192.168.1.76) when on local network
- Use public IP (185.96.221.52) when on external networks
- Or enable NAT loopback in router (if supported)

**Current Status**: Our router supports hairpinning - both local and external devices can use public IP.

## Dynamic DNS (DDNS)

**Problem**: Public IP may change when ISP reassigns it.

**Solution**: Use Dynamic DNS service to map a domain name to changing IP.

**Services**:
- No-IP (free)
- DynDNS
- Duck DNS (free)
- Cloudflare (free with domain)

**Setup**:
1. Register with DDNS service
2. Choose hostname (e.g., firefly.ddns.net)
3. Configure router's DDNS settings OR run DDNS client on Mac mini
4. Use hostname instead of IP in app

**Example**:
```swift
// Instead of:
let url = "http://185.96.221.52:8080/api/ping"

// Use:
let url = "http://firefly.ddns.net:8080/api/ping"
```

## Security Considerations

### Firewall

Ensure macOS firewall allows connections:
- System Settings → Network → Firewall
- Allow Python or specific app

### Port Choice

- **Port 8080**: Common alternative HTTP port
- **Not blocked**: Most ISPs don't block port 8080
- **Production**: Consider standard port 443 (HTTPS) for production

### HTTPS/TLS

Current setup uses HTTP (unencrypted). For production:

1. **Get domain name** (via DDNS or purchase)
2. **Get TLS certificate** (Let's Encrypt - free)
3. **Configure HTTPS** in Flask or use nginx reverse proxy
4. **Forward port 443** instead of 8080

## Troubleshooting

### Can't access via public IP

```bash
# Test if server is running
curl http://localhost:8080/api/ping

# Test local network access
curl http://192.168.1.76:8080/api/ping

# Check public IP hasn't changed
curl https://api.ipify.org

# Test port forwarding from external network
curl http://185.96.221.52:8080/api/ping
```

### Connection timeout

- Router port forwarding not configured
- ISP blocking incoming connections
- Firewall blocking port

### Connection refused

- Server not running
- Server not listening on 0.0.0.0
- Wrong port number

### Public IP changed

- Set up DDNS
- Update app configuration with new IP

## Current Network Status

The Firefly server is currently configured with:
- ✅ Port forwarding: 8080 → 192.168.1.76:8080
- ✅ Static local IP: 192.168.1.76 (via DHCP reservation or manual)
- ✅ macOS firewall: Allowing connections
- ✅ Server binding: 0.0.0.0:8080 (all interfaces)
- ✅ NAT loopback: Supported (can use public IP from local network)
- ❌ DDNS: Not configured (using direct IP)
- ❌ HTTPS: Not configured (using HTTP)

This setup is suitable for development and testing on a home network.
