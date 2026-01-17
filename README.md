# dnstt-docker

Docker images for [dnstt](https://www.bamsoftware.com/software/dnstt) - a DNS tunnel with DoH/DoT/UDP support. Built from official source code.

## Images

| Image | Description |
|-------|-------------|
| `ghcr.io/0xf00f00/dnstt-server` | DNS tunnel server |
| `ghcr.io/0xf00f00/dnstt-client` | DNS tunnel client |

## DNS Domain Setup

Before deploying, configure your domain's DNS records:

### Example Configuration
- **Your domain**: `example.com`
- **Server IP**: `203.0.113.2`
- **Tunnel subdomain**: `t.example.com`

### DNS Records

| Type | Name | Points to |
|------|------|-----------|
| A | `tns.example.com` | `203.0.113.2` |
| AAAA | `tns.example.com` | `2001:db8::2` (optional) |
| NS | `t.example.com` | `tns.example.com` |

> **Note**: Wait for DNS propagation (up to 24 hours) before testing.

## Server Setup

### Quick Start

```bash
docker run -d \
  --name dnstt-server \
  -p 53:5300/udp \
  -v dnstt-keys:/etc/dnstt \
  -e DNSTT_DOMAIN=t.example.com \
  -e DNSTT_FORWARD_ADDR=127.0.0.1:1080 \
  ghcr.io/0xf00f00/dnstt-server
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DNSTT_DOMAIN` | Tunnel subdomain (required) | - |
| `DNSTT_FORWARD_ADDR` | Forward tunneled connections to | `127.0.0.1:1080` |
| `DNSTT_MTU` | MTU value for DNS responses | `1232` |
| `DNSTT_LISTEN_PORT` | UDP port to listen on | `5300` |

### Key Management

Keys are automatically generated on first run and stored in `/etc/dnstt`. Mount a volume to persist keys across restarts.

The public key is printed to stdout on startup - share this with clients.

## Client Setup

### Quick Start

```bash
docker run -d \
  --name dnstt-client \
  -p 7000:7000 \
  -e DNSTT_DOMAIN=t.example.com \
  -e DNSTT_PUBKEY="YOUR_PUBLIC_KEY_HERE" \
  -e DNSTT_DOH_URL=https://cloudflare-dns.com/dns-query \
  ghcr.io/0xf00f00/dnstt-client
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DNSTT_DOMAIN` | Tunnel subdomain (required) | - |
| `DNSTT_PUBKEY` | Server public key (required) | - |
| `DNSTT_DOH_URL` | DoH resolver URL | - |
| `DNSTT_DOT_ADDR` | DoT resolver (e.g., `1.1.1.1:853`) | - |
| `DNSTT_UDP_ADDR` | UDP resolver (e.g., `8.8.8.8:53`) | - |
| `DNSTT_LISTEN_ADDR` | Local listen address | `127.0.0.1:7000` |

> **Note**: One of `DNSTT_DOH_URL`, `DNSTT_DOT_ADDR`, or `DNSTT_UDP_ADDR` is required.

### Resolver Options

| Mode | Variable | Example |
|------|----------|---------|
| DNS over HTTPS | `DNSTT_DOH_URL` | `https://cloudflare-dns.com/dns-query` |
| DNS over TLS | `DNSTT_DOT_ADDR` | `1.1.1.1:853` |
| Plain UDP | `DNSTT_UDP_ADDR` | `8.8.8.8:53` |

## Docker Compose Examples

### Server

Runs an isolated SSH server in Docker - users can only use it as a tunnel, not access your host.

```yaml
services:
  dnstt-server:
    image: ghcr.io/0xf00f00/dnstt-server:latest
    restart: unless-stopped
    ports:
      - "53:5300/udp"
    volumes:
      - dnstt-keys:/etc/dnstt
    environment:
      - DNSTT_DOMAIN=t.example.com
      - DNSTT_FORWARD_ADDR=ssh-server:22
      - DNSTT_MTU=1232
    depends_on:
      - ssh-server

  ssh-server:
    image: linuxserver/openssh-server
    restart: unless-stopped
    environment:
      - PASSWORD_ACCESS=true
      - USER_NAME=tunnel
      - USER_PASSWORD=your-secure-password

volumes:
  dnstt-keys:
```

### Client

```yaml
services:
  dnstt-client:
    image: ghcr.io/0xf00f00/dnstt-client:latest
    restart: unless-stopped
    ports:
      - "7000:7000"
    environment:
      - DNSTT_DOMAIN=t.example.com
      - DNSTT_PUBKEY=0000000000000000000000000000000000000000000000000000000000000000
      - DNSTT_DOH_URL=https://cloudflare-dns.com/dns-query
      - DNSTT_LISTEN_ADDR=0.0.0.0:7000
```

After starting, connect via SSH with dynamic port forwarding:

```bash
ssh -D 1080 -p 7000 tunnel@localhost
```

Enter the password when prompted. Applications can use `localhost:1080` as a SOCKS proxy.

### Using SSH Keys (Recommended)

For automated connections with auto-reconnect, use key-based auth with `jnovack/autossh`:

**Server** - change to key-based auth:
```yaml
ssh-server:
  image: linuxserver/openssh-server
  environment:
    - PASSWORD_ACCESS=false
    - USER_NAME=tunnel
  volumes:
    - ./authorized_keys:/config/.ssh/authorized_keys:ro
```

**Client** - use autossh for reliable reconnection:
```yaml
services:
  dnstt-client:
    image: ghcr.io/0xf00f00/dnstt-client:latest
    restart: unless-stopped
    environment:
      - DNSTT_DOMAIN=t.example.com
      - DNSTT_PUBKEY=0000000000000000000000000000000000000000000000000000000000000000
      - DNSTT_DOH_URL=https://cloudflare-dns.com/dns-query
      - DNSTT_LISTEN_ADDR=0.0.0.0:7000

  ssh-tunnel:
    image: jnovack/autossh
    restart: unless-stopped
    depends_on:
      - dnstt-client
    ports:
      - "1080:1080"
    environment:
      - SSH_HOSTUSER=tunnel
      - SSH_HOSTNAME=dnstt-client
      - SSH_HOSTPORT=7000
      - SSH_MODE=-D 0.0.0.0:1080
      - AUTOSSH_GATETIME=0
    volumes:
      - ./id_rsa:/id_rsa:ro
```

## Troubleshooting

### Port 53 Already in Use

If port 53 is occupied (e.g., by systemd-resolved on Ubuntu), use iptables forwarding:

```bash
# Map Docker to port 5300
docker run -d -p 5300:5300/udp ...

# Forward external port 53 to 5300
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
```
