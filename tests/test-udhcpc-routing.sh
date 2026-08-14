#!/bin/sh
set -eu

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM
mkdir -p "$TEST_ROOT/bin"

cat > "$TEST_ROOT/bin/ip" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$IP_LOG"
case "$*" in
    "-4 route show dev iptv scope link")
        echo "10.0.0.0/10 proto kernel scope link src 10.61.131.94"
        ;;
    "-4 link show dev iptv")
        echo "42: iptv: <UP>"
        ;;
esac
EOF
chmod 700 "$TEST_ROOT/bin/ip"

assert_contains() {
    pattern=$1
    file=$2
    if ! grep -Fq -- "$pattern" "$file"; then
        echo "Expected to find: $pattern" >&2
        cat "$file" >&2
        exit 1
    fi
}

assert_not_contains() {
    pattern=$1
    file=$2
    if grep -Fq -- "$pattern" "$file"; then
        echo "Did not expect to find: $pattern" >&2
        cat "$file" >&2
        exit 1
    fi
}

run_hook() {
    IP_LOG=$1
    export IP_LOG
    : > "$IP_LOG"
    if ! env \
        IPTV_COMMAND_PATH="$TEST_ROOT/bin:/usr/bin:/bin" \
        interface=iptv \
        ip=10.61.131.94 \
        mask=10 \
        subnet=255.192.0.0 \
        broadcast=10.63.255.255 \
        router= \
        staticroutes="0.0.0.0/0 10.0.0.1 10.0.0.0/10 0.0.0.0" \
        IPTV_ROUTE_TABLE="$2" \
        IPTV_ALLOW_MAIN_DEFAULT_ROUTE="$3" \
        sh ./udhcpc.hook bound 2> "$TEST_ROOT/stderr"; then
        cat "$TEST_ROOT/stderr" >&2
        exit 1
    fi
}

run_hook "$TEST_ROOT/isolated.log" 185 false
assert_contains "route replace table 185 10.0.0.0/10 dev iptv scope link src 10.61.131.94 proto 99" "$TEST_ROOT/isolated.log"
assert_contains "route replace table 185 default via 10.0.0.1 dev iptv onlink" "$TEST_ROOT/isolated.log"
assert_contains "route replace table 185 10.0.0.0/10 dev iptv scope link" "$TEST_ROOT/isolated.log"
assert_not_contains "route replace default via 10.0.0.1" "$TEST_ROOT/isolated.log"

run_hook "$TEST_ROOT/main-safe.log" main false
assert_not_contains "route replace default via 10.0.0.1" "$TEST_ROOT/main-safe.log"
assert_contains "Ignoring IPTV DHCP default route" "$TEST_ROOT/stderr"

run_hook "$TEST_ROOT/main-opt-in.log" main true
assert_contains "route replace default via 10.0.0.1 dev iptv onlink" "$TEST_ROOT/main-opt-in.log"

echo "udhcpc routing tests passed"
