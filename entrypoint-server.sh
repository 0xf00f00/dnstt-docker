#!/bin/sh
set -e

KEY_DIR="/etc/dnstt"
PRIVKEY_FILE="${KEY_DIR}/server.key"
PUBKEY_FILE="${KEY_DIR}/server.pub"

# Validate required environment variables
if [ -z "$DNSTT_DOMAIN" ]; then
    echo "ERROR: DNSTT_DOMAIN environment variable is required"
    echo "Example: DNSTT_DOMAIN=t.example.com"
    exit 1
fi

# Generate keys if they don't exist
if [ ! -f "$PRIVKEY_FILE" ] || [ ! -f "$PUBKEY_FILE" ]; then
    echo "Generating new keypair..."
    dnstt-server -gen-key -privkey-file "$PRIVKEY_FILE" -pubkey-file "$PUBKEY_FILE"
    echo "Keys generated successfully."
    echo ""
    echo "=========================================="
    echo "PUBLIC KEY (share with clients):"
    echo "=========================================="
    cat "$PUBKEY_FILE"
    echo ""
    echo "=========================================="
else
    echo "Using existing keypair."
    echo "Public key:"
    cat "$PUBKEY_FILE"
    echo ""
fi

echo "Starting dnstt-server..."
echo "  Domain: $DNSTT_DOMAIN"
echo "  Forward: $DNSTT_FORWARD_ADDR"
echo "  MTU: $DNSTT_MTU"
echo "  Listen: :$DNSTT_LISTEN_PORT/udp"

exec dnstt-server \
    -udp ":${DNSTT_LISTEN_PORT}" \
    -privkey-file "$PRIVKEY_FILE" \
    -mtu "$DNSTT_MTU" \
    "$DNSTT_DOMAIN" \
    "$DNSTT_FORWARD_ADDR"
