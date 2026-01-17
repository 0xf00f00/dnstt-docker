#!/bin/sh
set -e

# Validate required environment variables
if [ -z "$DNSTT_DOMAIN" ]; then
    echo "ERROR: DNSTT_DOMAIN environment variable is required"
    echo "Example: DNSTT_DOMAIN=t.example.com"
    exit 1
fi

if [ -z "$DNSTT_PUBKEY" ]; then
    echo "ERROR: DNSTT_PUBKEY environment variable is required"
    echo "This is the base64-encoded public key from the server"
    exit 1
fi

# Determine resolver mode
RESOLVER_ARGS=""
if [ -n "$DNSTT_DOH_URL" ]; then
    RESOLVER_ARGS="-doh $DNSTT_DOH_URL"
    echo "Using DoH resolver: $DNSTT_DOH_URL"
elif [ -n "$DNSTT_DOT_ADDR" ]; then
    RESOLVER_ARGS="-dot $DNSTT_DOT_ADDR"
    echo "Using DoT resolver: $DNSTT_DOT_ADDR"
elif [ -n "$DNSTT_UDP_ADDR" ]; then
    RESOLVER_ARGS="-udp $DNSTT_UDP_ADDR"
    echo "Using UDP resolver: $DNSTT_UDP_ADDR"
else
    echo "ERROR: One of DNSTT_DOH_URL, DNSTT_DOT_ADDR, or DNSTT_UDP_ADDR is required"
    echo "Examples:"
    echo "  DNSTT_DOH_URL=https://cloudflare-dns.com/dns-query"
    echo "  DNSTT_DOT_ADDR=1.1.1.1:853"
    echo "  DNSTT_UDP_ADDR=8.8.8.8:53"
    exit 1
fi

echo "Starting dnstt-client..."
echo "  Domain: $DNSTT_DOMAIN"
echo "  Listen: $DNSTT_LISTEN_ADDR"

exec dnstt-client \
    $RESOLVER_ARGS \
    -pubkey "$DNSTT_PUBKEY" \
    "$DNSTT_DOMAIN" \
    "$DNSTT_LISTEN_ADDR"
