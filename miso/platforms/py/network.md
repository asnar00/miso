# Network Configuration
*Setting up network access for servers*

Generic knowledge for configuring routers and networks to make local servers accessible from the internet.

## Port Forwarding

Port forwarding redirects incoming traffic from the router's public IP to a specific device on the local network.

### Why Port Forwarding is Needed

- **Problem**: Devices on local network (192.168.x.x) are not directly accessible from internet
- **Solution**: Router forwards requests on public IP:PORT to local device IP:PORT
- **Result**: Internet clients can reach services running on local network

### Router Configuration Steps

The exact steps vary by router, but generally:

1. **Access Router Admin Panel**:
   - Open browser to router IP (typically 192.168.1.1 or 192.168.0.1)
   - Login with admin credentials

2. **Find Port Forwarding Section**:
   - Usually under "Advanced Settings"
   - May be called "Port Forwarding", "Virtual Server", "NAT Forwarding", or "Applications"

3. **Add Port Forwarding Rule**:
   - **Service Name**: Descriptive name for the service
   - **External Port**: Port on public IP
   - **Internal IP**: Local IP of the server device
   - **Internal Port**: Port on local device (often same as external)
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

Configure router to always assign same IP to a device:

1. Find device's MAC address:
   ```bash
   ifconfig en0 | grep ether  # macOS
   ip link show              # Linux
   ```
   Output: `ether xx:xx:xx:xx:xx:xx`

2. In router admin panel:
   - Find DHCP Settings or Address Reservation
   - Add reservation: MAC address → desired IP
   - Save

**Benefit**: IP stays consistent even if device restarts

### Option 2: Manual Static IP

Configure device with static IP:

**macOS**:
1. System Settings → Network
2. Select WiFi/Ethernet connection
3. Details → TCP/IP
4. Configure IPv4: Manually
5. Set:
   - IP Address: e.g., 192.168.1.100
   - Subnet Mask: 255.255.255.0
   - Router: 192.168.1.1 (your router's IP)
   - DNS: 8.8.8.8, 8.8.4.4 (Google DNS) or your ISP's DNS

**Linux**:
Edit `/etc/network/interfaces` or use NetworkManager/netplan

**Downside**: Must configure on each network

## Testing Port Forwarding

### Test from Local Network

```bash
curl http://LOCAL_IP:PORT/path
```

### Test from Internet

From device NOT on local network (e.g., mobile data):
```bash
curl http://PUBLIC_IP:PORT/path
```

### Port Forwarding Checklist

If external access doesn't work:

- [ ] Server running and bound to 0.0.0.0:PORT (not 127.0.0.1)
- [ ] Local access works (LOCAL_IP:PORT)
- [ ] Port forwarding rule created (PORT → LOCAL_IP:PORT)
- [ ] Rule is enabled/active
- [ ] Device has static local IP
- [ ] Device firewall allows incoming connections on PORT
- [ ] ISP doesn't block incoming traffic on PORT
- [ ] Public IP is current (check whatismyip.com)

## NAT Loopback (Hairpinning)

**Issue**: Some routers don't support accessing public IP from inside local network.

**Symptom**:
- External devices can reach public IP ✓
- Local devices get connection refused when using public IP ✗

**Workaround**:
- Use local IP when on local network
- Use public IP when on external networks
- Or enable NAT loopback in router (if supported)

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
2. Choose hostname (e.g., myserver.ddns.net)
3. Configure router's DDNS settings OR run DDNS client on server
4. Use hostname instead of IP in applications

**Example**:
```
# Instead of:
http://203.0.113.45:8080/api/endpoint

# Use:
http://myserver.ddns.net:8080/api/endpoint
```

## Security Considerations

### Port Choice

- Ports 1-1023: Reserved, require root/admin privileges
- Port 80: Standard HTTP (may be blocked by ISP)
- Port 443: Standard HTTPS (recommended for production)
- Ports 8000-8999: Common alternative HTTP ports
- Always check if your ISP blocks specific ports

### HTTPS/TLS

For production deployments:

1. **Get domain name** (via DDNS or purchase)
2. **Get TLS certificate** (Let's Encrypt - free)
3. **Configure HTTPS** in your server or use reverse proxy
4. **Forward port 443** instead of HTTP port

### Firewall Rules

- Only forward ports you actually need
- Use specific internal IP (not DMZ/all ports)
- Keep router firmware updated
- Use strong admin passwords

## Troubleshooting

### Can't access via public IP

```bash
# Test if server is running
curl http://localhost:PORT/path

# Test local network access
curl http://LOCAL_IP:PORT/path

# Check public IP hasn't changed
curl https://api.ipify.org

# Test from external network
curl http://PUBLIC_IP:PORT/path
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
- Update configuration with new IP
