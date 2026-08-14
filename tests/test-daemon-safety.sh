#!/bin/sh
set -eu

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM
mkdir -p "$TEST_ROOT/bin"

cat > "$TEST_ROOT/bin/ip" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$IP_LOG"
case "$*" in
    "link show eth4"|"link show br85") exit 0 ;;
    "link show iptv") [ -f "$LINK_STATE" ] ; exit $? ;;
    "link add link eth4 name iptv type vlan id 85") touch "$LINK_STATE"; exit 0 ;;
    "link delete dev iptv") rm -f "$LINK_STATE"; exit 0 ;;
    "-4 rule del "*) exit 1 ;;
esac
exit 0
EOF

cat > "$TEST_ROOT/bin/iptables" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$IPTABLES_LOG"
case " $* " in
    *" -C "*) [ -f "$NAT_STATE" ]; exit $? ;;
    *" -A "*) touch "$NAT_STATE"; exit 0 ;;
    *" -D "*) rm -f "$NAT_STATE"; exit 0 ;;
esac
exit 0
EOF

cat > "$TEST_ROOT/bin/igmpproxy" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PROXY_LOG"
exit 0
EOF

chmod 700 "$TEST_ROOT/bin/ip" "$TEST_ROOT/bin/iptables" "$TEST_ROOT/bin/igmpproxy"

export PATH="$TEST_ROOT/bin:/usr/bin:/bin"
export IP_LOG="$TEST_ROOT/ip.log"
export IPTABLES_LOG="$TEST_ROOT/iptables.log"
export PROXY_LOG="$TEST_ROOT/proxy.log"
export LINK_STATE="$TEST_ROOT/iptv-link"
export NAT_STATE="$TEST_ROOT/nat-rule"
export IPTV_POLICY_STATE_FILE="$TEST_ROOT/policy-rules"
export IPTV_NAT_STATE_FILE="$TEST_ROOT/nat-rules"
export IPTV_IGMPPROXY_CONFIG_FILE="$TEST_ROOT/igmpproxy.conf"
export IPTV_WAN_INTERFACE=eth4
export IPTV_WAN_VLAN=85
export IPTV_WAN_VLAN_INTERFACE=iptv
export IPTV_WAN_DHCP=false
export IPTV_WAN_STATIC_IP=10.61.131.94/10
export IPTV_WAN_RANGES=0.0.0.0/0
export IPTV_STATIC_ROUTES=
export IPTV_LAN_INTERFACES=br85
export IPTV_ROUTE_TABLE=185
export IPTV_ROUTE_RULE_PRIORITY=18500
export IPTV_ALLOW_MAIN_DEFAULT_ROUTE=false
export IPTV_NAT_ENABLE=true
export IPTV_ALLOW_UNSCOPED_NAT=false
export IPTV_IGMPPROXY_PROGRAM=igmpproxy
export IPTV_IGMPPROXY_DISABLE_QUICKLEAVE=true
export IPTV_IGMPPROXY_DEBUG=false

assert_contains() {
    pattern=$1
    file=$2
    if ! grep -Fq -- "$pattern" "$file"; then
        echo "Expected to find: $pattern" >&2
        cat "$file" >&2
        exit 1
    fi
}

export IPTV_NAT_SOURCE_RANGES=
if sh ./udm-iptvd validate > "$TEST_ROOT/unsafe.out" 2>&1; then
    echo "Unsafe 0/0 NAT unexpectedly passed validation" >&2
    exit 1
fi
assert_contains "refusing unscoped IPTV NAT" "$TEST_ROOT/unsafe.out"

export IPTV_NAT_SOURCE_RANGES=192.168.85.0/24
sh ./udm-iptvd validate

: > "$IP_LOG"
: > "$IPTABLES_LOG"
: > "$PROXY_LOG"
sh ./udm-iptvd start

assert_contains "-4 rule add priority 18500 iif br85 lookup 185" "$IP_LOG"
assert_contains "-A POSTROUTING -t nat -s 192.168.85.0/24 -d 0.0.0.0/0 -j MASQUERADE -o iptv" "$IPTABLES_LOG"
assert_contains "-n $TEST_ROOT/igmpproxy.conf" "$PROXY_LOG"

sh ./udm-iptvd stop
assert_contains "-4 rule del priority 18500 iif br85 lookup 185" "$IP_LOG"
assert_contains "link delete dev iptv" "$IP_LOG"
assert_contains "-D POSTROUTING -t nat -s 192.168.85.0/24 -d 0.0.0.0/0 -j MASQUERADE -o iptv" "$IPTABLES_LOG"
[ ! -e "$LINK_STATE" ]
[ ! -e "$NAT_STATE" ]
[ ! -e "$IPTV_POLICY_STATE_FILE" ]
[ ! -e "$IPTV_NAT_STATE_FILE" ]

echo "daemon safety tests passed"
