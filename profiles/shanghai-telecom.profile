#!/bin/sh -e
# Profile for Shanghai Telecom IPTV (CN), tailored for a UCG Fiber with a
# dedicated IPTV client VLAN and an independent primary/backup WAN setup.

db_get udm-iptv/wan-port
db_set udm-iptv/wan-interface "$RET"

db_set udm-iptv/wan-vlan 85
db_set udm-iptv/wan-ranges "0.0.0.0/0"
db_set udm-iptv/wan-dhcp true
db_set udm-iptv/wan-dhcp-options "-o -O subnet -O broadcast -O staticroutes"
db_set udm-iptv/lan-interfaces "br85"

# Never let the IPTV DHCP lease participate in the main WAN routing table.
db_set udm-iptv/route-table 185
db_set udm-iptv/route-rule-priority 18500
db_set udm-iptv/allow-main-default-route false

# A 0/0 provider range is only safe when NAT is constrained to the IPTV VLAN.
db_set udm-iptv/nat-enable true
db_set udm-iptv/nat-source-ranges "192.168.85.0/24"
db_set udm-iptv/allow-unscoped-nat false

# Prefer igmpproxy when it is already available, but use the UniFi-provided
# improxy binary on stock UCG Fiber installations instead of pulling in and
# auto-registering another system service during the migration.
proxy_program=improxy
if command -v igmpproxy >/dev/null 2>&1; then
    proxy_program=igmpproxy
fi
db_set udm-iptv/igmpproxy-program "$proxy_program"
db_set udm-iptv/igmpproxy-quickleave false
