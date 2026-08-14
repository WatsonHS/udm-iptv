#!/bin/sh

set -eu

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

cat > "$TEST_ROOT/udm-iptv.conf" <<'EOF'
IPTV_WAN_INTERFACE="eth4"
IPTV_WAN_VLAN="85"
IPTV_LAN_INTERFACES="br85"
IPTV_ROUTE_TABLE="185"
IPTV_NAT_SOURCE_RANGES="192.168.85.0/24"
EOF

cat > "$TEST_ROOT/fake-daemon" <<'EOF'
#!/bin/sh
set -eu

[ "$1" = "validate" ]
[ "$IPTV_WAN_INTERFACE" = "eth4" ]
[ "$IPTV_WAN_VLAN" = "85" ]
[ "$IPTV_LAN_INTERFACES" = "br85" ]
[ "$IPTV_ROUTE_TABLE" = "185" ]
[ "$IPTV_NAT_SOURCE_RANGES" = "192.168.85.0/24" ]
EOF
chmod +x "$TEST_ROOT/fake-daemon"

output=$(
    UDM_IPTV_CONFIG_FILE="$TEST_ROOT/udm-iptv.conf" \
    UDM_IPTV_DAEMON="$TEST_ROOT/fake-daemon" \
    ./udm-iptv validate
)

[ "$output" = "Configuration is safe to start." ]

echo "CLI validation tests passed"
