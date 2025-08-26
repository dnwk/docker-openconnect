# OpenConnect VPN Server with Automatic SSL Management

[preview]: https://raw.githubusercontent.com/MarkusMcNugen/docker-templates/master/openconnect/ocserv-icon.png "Custom ocserv icon"

![alt text][preview]

## 🚀 Overview

OpenConnect VPN server is an SSL VPN server that is secure, small, fast and configurable. This **enhanced version** includes **automatic SSL certificate management** using acme.sh with Let's Encrypt, making it production-ready with minimal configuration.

**🆕 New in this version:**
- ✅ **Automatic SSL certificate generation and renewal**
- ✅ **Let's Encrypt integration with multiple challenge methods**
- ✅ **Periodic certificate monitoring (every 12 hours)**
- ✅ **Centralized volume management** - all files in `/etc/ocserv`
- ✅ **Production-ready logging and monitoring**
- ✅ **Self-signed certificate fallback**
- ✅ **Zero-downtime certificate renewal**

---

## 🌟 Key Features

### 🔐 SSL Certificate Management
- **Automatic certificate generation** using Let's Encrypt via acme.sh
- **Smart renewal logic** - renews certificates within 15 days of expiration
- **Multiple challenge methods**: HTTP standalone, DNS challenge, webroot
- **Automatic startup validation** - checks certificates on every container boot
- **Graceful fallback** to self-signed certificates if Let's Encrypt fails
- **Zero-downtime renewal** with automatic OpenConnect reload
- **Comprehensive logging** for troubleshooting

### 🐳 Enhanced Docker Features
- **Persistent configuration**: Single `/etc/ocserv` volume mount preserves everything
- **Centralized file management**: Configs, certificates, logs, and user data in one place
- **Flexible SSL configuration**: Support for custom domains and challenge methods
- **Production-ready**: Automatic certificate management with proper logging
- **Backward compatibility**: Works with existing OpenConnect configurations

### 🌐 Network Features
- **Full tunnel or split-tunnel** routing options
- **Customizable DNS servers** and split-DNS domains
- **Multiple authentication methods** (password, certificate, RADIUS)
- **Client compatibility**: OpenConnect and Cisco AnyConnect clients
- **IPv4 and IPv6 support**
- **Traffic compression** and optimization

---

## 🚀 Quick Start

### Method 1: Docker Compose (Recommended)

1. **Create docker-compose.yml**:
```yaml
version: '3.8'
services:
  openconnect:
    build: .
    container_name: openconnect-vpn
    privileged: true
    restart: unless-stopped
    ports:
      - "4443:4443/tcp"
      - "4443:4443/udp" 
      - "80:80/tcp"  # For Let's Encrypt HTTP challenge
    volumes:
      - ./ocserv-data:/etc/ocserv
    environment:
      - SSL_DOMAIN=vpn.yourdomain.com  # Change this!
      - ACME_STANDALONE=true
      - DNS_SERVERS=8.8.8.8,1.1.1.1
      - TUNNEL_MODE=all
```

2. **Start the service**:
```bash
docker-compose up -d
```

3. **Add users** (see User Management section below)

### Method 2: Docker Run Command

```bash
# Create data directory
mkdir -p ./ocserv-data

# Run with automatic SSL
docker run -d --privileged \
  --name openconnect-vpn \
  -p 4443:4443/tcp \
  -p 4443:4443/udp \
  -p 80:80/tcp \
  -v ./ocserv-data:/etc/ocserv \
  -e SSL_DOMAIN=vpn.yourdomain.com \
  -e ACME_STANDALONE=true \
  your-registry/openconnect-ssl
```

---

## 🔧 Configuration Guide

### Environment Variables

#### 🔐 SSL Certificate Management
| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| `SSL_DOMAIN` | ⚠️ Recommended | `vpn.example.com` | Domain name for SSL certificate | `vpn.yourdomain.com` |
| `ACME_STANDALONE` | No | `false` | Use HTTP standalone challenge (port 80) | `true` |
| `ACME_DNS_PROVIDER` | No | - | DNS provider for DNS challenge | `dns_cf` (Cloudflare) |
| `ACME_WEBROOT` | No | `/etc/ocserv/webroot` | Webroot path for HTTP challenge | `/var/www/html` |
| `DISABLE_SSL_AUTO` | No | `false` | Disable automatic SSL management | `true` |

#### 🌐 OpenConnect Server Settings
| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| `LISTEN_PORT` | No | `4443` | VPN listening port | `443` |
| `DNS_SERVERS` | No | Google/FreeDNS | Comma-delimited name servers | `8.8.8.8,1.1.1.1` |
| `TUNNEL_MODE` | No | `all` | Tunnel mode | `all` or `split-include` |
| `TUNNEL_ROUTES` | No | - | Routes for split tunneling | `192.168.1.0/24,10.0.0.0/16` |
| `SPLIT_DNS_DOMAINS` | No | - | Split-DNS domains | `local.com,corp.internal` |
| `POWER_USER` | No | `no` | Disable automatic config updates | `yes` |

### Volume Structure

When you mount `/etc/ocserv`, this directory structure is automatically created:

```
/etc/ocserv/                    # Main configuration directory
├── ocserv.conf                 # 📄 OpenConnect server configuration
├── ocpasswd                    # 👥 User password database
├── connect.sh                  # 🔌 Client connection script
├── disconnect.sh               # 🔌 Client disconnection script
├── certs/                      # 🔐 SSL certificates directory
│   ├── server-cert.pem         #     Server certificate
│   ├── server-key.pem          #     Server private key
│   └── ca.pem                  #     CA certificate (optional)
├── logs/                       # 📋 Log files directory
│   ├── ssl-manager.log         #     SSL management logs
│   └── ssl-check.log           #     Periodic SSL check logs
├── config-per-user/            # 👤 Per-user configurations
├── config-per-group/           # 👥 Per-group configurations
└── webroot/                    # 🌐 Webroot for HTTP challenge (if used)
```

---

## 🔐 SSL Certificate Management Guide

### Automatic Certificate Lifecycle

The container automatically manages SSL certificates through this process:

```mermaid
graph TD
    A[Container Starts] --> B{SSL Auto Enabled?}
    B -->|No| C[Use Self-Signed]
    B -->|Yes| D{Certificate Exists?}
    D -->|No| E[Request New Certificate]
    D -->|Yes| F{Expires in <15 days?}
    F -->|No| G[Continue Normal Operation]
    F -->|Yes| H[Renew Certificate]
    E --> I{Let's Encrypt Success?}
    I -->|Yes| J[Install Certificate]
    I -->|No| C
    H --> K{Renewal Success?}
    K -->|Yes| L[Reload OpenConnect]
    K -->|No| M[Log Error & Continue]
```

### SSL Challenge Methods

#### 1. 🌐 HTTP Standalone Challenge (Easiest)
**Best for**: Simple setups, single domain

```yaml
environment:
  - SSL_DOMAIN=vpn.yourdomain.com
  - ACME_STANDALONE=true
ports:
  - "80:80"  # Required for HTTP challenge
```

**Requirements**: Port 80 must be accessible from the internet

#### 2. 🔍 DNS Challenge (Most Flexible)
**Best for**: Wildcard certificates, behind firewall, multiple domains

**Cloudflare Example**:
```yaml
environment:
  - SSL_DOMAIN=vpn.yourdomain.com
  - ACME_DNS_PROVIDER=dns_cf
  - CF_Token=your_cloudflare_token
  - CF_Account_ID=your_account_id
```

**Other DNS Providers**:
- `dns_aws` (AWS Route53)
- `dns_gd` (GoDaddy) 
- `dns_he` (Hurricane Electric)
- See [acme.sh DNS providers](https://github.com/acmesh-official/acme.sh/wiki/dnsapi) for full list

#### 3. 📁 Webroot Challenge
**Best for**: Existing web server setup

```yaml
environment:
  - SSL_DOMAIN=vpn.yourdomain.com
  - ACME_WEBROOT=/var/www/html
volumes:
  - ./webroot:/var/www/html
```

### Manual SSL Certificate Management

#### Check Certificate Status
```bash
# Check current certificate
docker exec -it openconnect-vpn /usr/local/bin/ssl-manager.sh check

# View certificate details
docker exec -it openconnect-vpn openssl x509 -in /etc/ocserv/certs/server-cert.pem -text -noout
```

#### Force Certificate Renewal
```bash
# Force immediate renewal
docker exec -it openconnect-vpn /usr/local/bin/ssl-manager.sh force

# Generate self-signed certificate
docker exec -it openconnect-vpn /usr/local/bin/ssl-manager.sh self-signed
```

#### View SSL Logs
```bash
# SSL management logs
docker exec -it openconnect-vpn tail -f /etc/ocserv/logs/ssl-manager.log

# Periodic check logs  
docker exec -it openconnect-vpn tail -f /etc/ocserv/logs/ssl-check.log
```

---

## 👥 User Management Guide

### Adding Users

#### Method 1: Interactive (Recommended)
```bash
docker exec -it openconnect-vpn ocpasswd -c /etc/ocserv/ocpasswd username
# Enter password when prompted
```

#### Method 2: Batch Creation
```bash
# Create multiple users from file
echo "user1:password1" | docker exec -i openconnect-vpn sh -c 'IFS=: read u p; echo "$p" | ocpasswd -c /etc/ocserv/ocpasswd "$u"'
```

### Managing Users

```bash
# List all users
docker exec -it openconnect-vpn cat /etc/ocserv/ocpasswd

# Delete user
docker exec -it openconnect-vpn ocpasswd -c /etc/ocserv/ocpasswd -d username

# Change password
docker exec -it openconnect-vpn ocpasswd -c /etc/ocserv/ocpasswd username

# Lock user account (disable)
docker exec -it openconnect-vpn ocpasswd -c /etc/ocserv/ocpasswd -l username

# Unlock user account
docker exec -it openconnect-vpn ocpasswd -c /etc/ocserv/ocpasswd -u username
```

### User Connection Monitoring

```bash
# View active connections
docker exec -it openconnect-vpn occtl show users

# View connection statistics
docker exec -it openconnect-vpn occtl show stats

# Disconnect specific user
docker exec -it openconnect-vpn occtl disconnect user USERNAME
```

---

## 🛠️ Advanced Configuration

### Split Tunneling Setup

```yaml
services:
  openconnect-split:
    build: .
    container_name: openconnect-split
    privileged: true
    ports:
      - "4443:4443/tcp"
      - "4443:4443/udp"
      - "80:80"
    volumes:
      - ./ocserv-split-data:/etc/ocserv
    environment:
      # Split tunneling configuration
      - SSL_DOMAIN=vpn-split.yourdomain.com
      - TUNNEL_MODE=split-include
      - TUNNEL_ROUTES=192.168.1.0/24,10.0.0.0/16,172.16.0.0/12
      - SPLIT_DNS_DOMAINS=local.example.com,internal.corp
      - DNS_SERVERS=192.168.1.1,8.8.8.8
      - ACME_STANDALONE=true
```

### Custom Configuration (Power User Mode)

If you need full control over the OpenConnect configuration:

1. **Set Power User Mode**:
```yaml
environment:
  - POWER_USER=yes
  - SSL_DOMAIN=vpn.yourdomain.com  # SSL still works
```

2. **Create custom ocserv.conf**:
```bash
# Copy default config first
docker run --rm -v ./custom-config:/tmp your-image cat /etc/default/ocserv/ocserv.conf > ./custom-config/ocserv.conf

# Edit the configuration file
nano ./custom-config/ocserv.conf
```

3. **Mount custom configuration**:
```yaml
volumes:
  - ./custom-config:/etc/ocserv
```

### Per-User/Group Configurations

Create specific configurations for different users or groups:

```bash
# Create user-specific config
mkdir -p ./ocserv-data/config-per-user
cat > ./ocserv-data/config-per-user/john.conf << EOF
# John's specific configuration
route = 192.168.100.0/255.255.255.0
dns = 192.168.1.10
idle-timeout = 7200
EOF

# Create group-specific config  
mkdir -p ./ocserv-data/config-per-group
cat > ./ocserv-data/config-per-group/admins.conf << EOF
# Admin group configuration
no-route = 10.10.10.0/255.255.255.0
max-same-clients = 3
EOF
```

Then enable in main config:
```bash
# Add to ocserv.conf
config-per-user = /etc/ocserv/config-per-user/
config-per-group = /etc/ocserv/config-per-group/
```

---

## 📊 Monitoring and Logging

### Container Logs
```bash
# View container logs
docker logs -f openconnect-vpn

# View last 100 lines
docker logs --tail 100 openconnect-vpn
```

### SSL Certificate Monitoring
```bash
# Check certificate expiration
docker exec -it openconnect-vpn openssl x509 -in /etc/ocserv/certs/server-cert.pem -noout -dates

# View SSL management activity
docker exec -it openconnect-vpn tail -f /etc/ocserv/logs/ssl-manager.log

# Check periodic SSL validation
docker exec -it openconnect-vpn tail -f /etc/ocserv/logs/ssl-check.log
```

### Connection Monitoring
```bash
# Real-time connection monitoring
docker exec -it openconnect-vpn tail -f /var/log/messages | grep ocserv

# View connection statistics
docker exec -it openconnect-vpn occtl show stats

# Monitor user connections
watch 'docker exec -it openconnect-vpn occtl show users'
```

### Performance Monitoring
```bash
# Container resource usage
docker stats openconnect-vpn

# Network traffic
docker exec -it openconnect-vpn iftop -i vpns

# Disk usage of persistent volume
du -sh ./ocserv-data/
```

---

## 🔧 Troubleshooting Guide

### Common Issues and Solutions

#### 🚫 SSL Certificate Issues

**Problem**: Certificate validation fails
```bash
# Check domain DNS resolution
nslookup vpn.yourdomain.com

# Test certificate manually
docker exec -it openconnect-vpn /usr/local/bin/ssl-manager.sh force

# Check SSL logs for errors
docker exec -it openconnect-vpn tail -50 /etc/ocserv/logs/ssl-manager.log
```

**Problem**: Let's Encrypt rate limit hit
```bash
# Use staging environment for testing
docker exec -it openconnect-vpn sh -c 'export ACME_STAGING=1; /usr/local/bin/ssl-manager.sh force'
```

#### 🌐 Connection Issues

**Problem**: Can't connect to VPN
```bash
# Check if ports are open
netstat -tulpn | grep 4443

# Test connectivity
telnet your-server-ip 4443

# Check firewall settings
iptables -L -n | grep 4443
```

**Problem**: DNS not working through VPN
```bash
# Check DNS configuration
docker exec -it openconnect-vpn grep "^dns" /etc/ocserv/ocserv.conf

# Test DNS resolution
docker exec -it openconnect-vpn nslookup google.com
```

#### 🐳 Docker Issues

**Problem**: Container won't start
```bash
# Check container logs
docker logs openconnect-vpn

# Verify privileged mode
docker inspect openconnect-vpn | grep Privileged

# Check volume mounts
docker inspect openconnect-vpn | grep Mounts -A 10
```

### Debug Mode

Enable verbose logging for troubleshooting:

```yaml
environment:
  - DEBUG=true
  - ACME_DEBUG=1  # Enable acme.sh debug
command: ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f", "-d", "1"]  # Debug level 1
```

---

## 🏗️ Building and Deployment

### Build from Source

```bash
# Clone repository
git clone https://github.com/MarkusMcNugen/docker-openconnect.git
cd docker-openconnect

# Build container
docker build -t openconnect-ssl .

# Run built container
docker run -d --privileged \
  --name openconnect-vpn \
  -p 4443:4443/tcp -p 4443:4443/udp -p 80:80 \
  -v ./ocserv-data:/etc/ocserv \
  -e SSL_DOMAIN=vpn.yourdomain.com \
  -e ACME_STANDALONE=true \
  openconnect-ssl
```

### Production Deployment Checklist

- [ ] Set strong passwords for all VPN users
- [ ] Configure proper SSL domain with valid DNS
- [ ] Set up DNS challenge if behind firewall (no port 80)
- [ ] Enable log rotation for persistent volumes
- [ ] Set up monitoring for certificate expiration
- [ ] Configure backup of `/etc/ocserv` volume
- [ ] Set container restart policy to `unless-stopped`
- [ ] Use network isolation where possible
- [ ] Enable fail2ban or similar for brute force protection
- [ ] Set up proper firewall rules

### Docker Swarm / Kubernetes

For container orchestration environments:

```yaml
# Docker Swarm example
version: '3.8'
services:
  openconnect:
    image: openconnect-ssl:latest
    deploy:
      replicas: 1
      placement:
        constraints: [node.role == manager]
    ports:
      - "4443:4443"
      - "80:80"
    volumes:
      - ocserv-data:/etc/ocserv
    environment:
      - SSL_DOMAIN=vpn.yourdomain.com
      - ACME_DNS_PROVIDER=dns_cf
      - CF_Token_FILE=/run/secrets/cf_token
    secrets:
      - cf_token

volumes:
  ocserv-data:

secrets:
  cf_token:
    external: true
```

---

## 🛡️ Security Considerations

### Best Practices

1. **Strong Authentication**
   - Use complex passwords (min 12 characters)
   - Consider certificate-based authentication
   - Implement account lockout policies

2. **Network Security**
   - Use non-standard ports when possible
   - Implement IP whitelisting for admin access
   - Regular security updates of container

3. **Certificate Security**
   - Use DNS challenge when possible (avoids port 80 exposure)
   - Monitor certificate expiration
   - Use strong encryption (RSA 2048+ or ECC)

4. **Monitoring**
   - Log all connection attempts
   - Set up alerts for failed authentications
   - Monitor unusual traffic patterns

5. **Data Protection**
   - Regular backups of user database and certificates
   - Secure storage of acme.sh account keys
   - Encrypt persistent volumes if possible

---

## 🤝 Support and Contributing

### Getting Help

- **Documentation**: Check this README and inline code comments
- **Logs**: Always check container and SSL manager logs first
- **Issues**: Search existing issues before creating new ones

### Reporting Issues

When reporting issues, please include:

1. **Environment details**: Docker version, host OS, etc.
2. **Configuration**: Docker Compose file (sanitized)
3. **Logs**: Container logs and SSL manager logs
4. **Steps to reproduce**: Clear reproduction steps

### Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes thoroughly
4. Update documentation as needed
5. Submit pull request with clear description

---

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

- **Original OpenConnect Docker**: [MarkusMcNugen](https://github.com/MarkusMcNugen/docker-openconnect)
- **OpenConnect Server**: [OpenConnect VPN Server](https://ocserv.gitlab.io/www/)
- **acme.sh**: [acme.sh - ACME Shell Script](https://github.com/acmesh-official/acme.sh)
- **Let's Encrypt**: [Free SSL/TLS Certificates](https://letsencrypt.org/)

---

## 🚀 Quick Reference Card

| Task | Command |
|------|---------|
| **Start VPN** | `docker-compose up -d` |
| **Add User** | `docker exec -it openconnect-vpn ocpasswd -c /etc/ocserv/ocpasswd username` |
| **Check SSL** | `docker exec -it openconnect-vpn /usr/local/bin/ssl-manager.sh check` |
| **View Logs** | `docker logs -f openconnect-vpn` |
| **Show Users** | `docker exec -it openconnect-vpn occtl show users` |
| **Renew SSL** | `docker exec -it openconnect-vpn /usr/local/bin/ssl-manager.sh force` |
| **Stop VPN** | `docker-compose down` |

---

*Happy VPN-ing! 🔒*