# IPTV on UniFi OS

This document describes how to set up IPTV on UniFi routing devices based on 
UniFi OS, such as the UniFi Dream Machine (UDM) or the UniFi Dream Router (UDR).
These instructions have been tested with the IPTV network from KPN
(ISP in the Netherlands).
However, the general approach should be applicable for other ISPs as well.

For getting IPTV to work on the legacy UniFi Security Gateway, please refer to
the [following guide](https://github.com/basmeerman/unifi-usg-kpn).

## Contents

1. [Global Design](#global-design)
2. [Prerequisites](#prerequisites)
3. [Setting up Internet Connection](#setting-up-internet-connection)
4. [Configuring Internal LAN](#configuring-internal-lan)
5. [Configuring Helper Tool](#configuring-helper-tool)
6. [Troubleshooting and Known Issues](#troubleshooting)

## Global Design

```
        Fiber
          |
    +----------+
    | FTTH NTU |
    +----------+
          |
      VLAN4 - IPTV
      VLAN6 - Internet
          |
      +--------+
      | Router |  - Ubiquiti UniFi device
      +--------+
          |
         LAN
          |
      +--------+
      | Switch |  - Ubiquiti UniFi Switch (Optional)
      +--------+
       |  |  |
       |  |  +-----------------------------+
       |  |                                |
       |  +-----------------+              |
       |                    |              |
+--------------+       +---------+      +-----+
| IPTV Decoder |       | WiFi AP |      | ... |
+--------------+       +---------+      +-----+
  - KPN IPTV
  - Netflix
```

# Prerequisites

Make sure you check the following prerequisites before trying the other steps:

1. The kernel on your UniFi device must support multicast routing
   in order to support IPTV. Please upgrade to the latest firmware.
2. The switches in-between the IPTV decoder and the UniFi device should have IGMP
   snooping enabled. They do not need to be from Ubiquiti necessarily.
3. The FTTP NTU (or any other type of modem) of your ISP must be connected to
   one of the WAN ports of your UniFi device.

## Setting up Internet Connection

The first step is to set up your internet connection to your ISP with the UniFi
device acting as modem, instead of some intermediate device. These steps might
differ per ISP, so please check the requirements for your ISP.

Below, we describe the steps for KPN. Feel free to update this document with the
steps necessary for your provider.

### KPN
If you are a customer of KPN, you can set up the WAN connection as follows:

1. In your UniFi Dashboard, go to **Settings > Internet**.
2. Select the WAN port that is connected to the FTTP NTU.
3. Enable **VLAN ID** and set it to 6 for KPN.
4. Set **IPv4 Connection** to _PPPoE_.
5. For KPN, **Username** should be set to `internet`.
6. For KPN, **Password** should be set to `internet`.

## Configuring Internal LAN

To operate correctly, the IPTV decoders on the internal LAN possibly require
additional DHCP options. You can add these DHCP options as follows:

1. In your UniFi Dashboard, go to **Settings > Networks**.
2. Select the LAN network on which IPTV will be used.
   We recommend creating a separate LAN network for IPTV traffic if possible in
   order to reduce interference of other devices on the network.
3. Enable **Advanced Configuration > IGMP Snooping**, so IPTV traffic is only
   sent to devices that should receive it.

## Configuring Helper Tool

Next, we will use the udm-iptv package to get IPTV working on your LAN.
This package uses [igmpproxy](https://github.com/pali/igmpproxy) to route 
multicast IPTV traffic between WAN and LAN.

### Installation
SSH into your machine and execute the commands below in UniFi OS (not in UbiOS).
```bash
sh -c "$(curl https://raw.githubusercontent.com/WatsonHS/udm-iptv/master/install.sh -sSf)"
```

This script will install the `udm-iptv` package onto your device.
The installation process supports various pre-defined configuration profiles for
popular IPTV providers. Below is a list of supported IPTV providers: 

|  Provider | Country | Supported                                                                                                           |
|----------:|:-------:|---------------------------------------------------------------------------------------------------------------------|
|       KPN |   NL    | Yes                                                                                                                 |
|    XS4ALL |   NL    | Yes                                                                                                                 |
|     Tweak |   NL    | Yes                                                                                                                 |
|    Solcon |   NL    | Yes                                                                                                                 |
|   Telekom |   DE    | [Manual configuration necessary](https://github.com/fabianishere/udm-iptv/discussions/8)                            |
| MagentaTV |   DE    | [Manual configuration necessary](https://github.com/fabianishere/udm-iptv/issues/2#issuecomment-1007413230)         |
|  Swisscom |   CH    | Yes                                                                                                                 |
|     Init7 |   CH    | Yes                                                                                                                 |
|       MEO |   PT    | Yes                                                                                                                 |
|        BT |   GB    | Yes                                                                                                                 |
|   Vivo SP |   BR    | Yes - Tested with GPON TP-Link TX-6610                                                                              |
|  Vivo GVT |   BR    | Yes - [Manual configuration necessary](https://github.com/fabianishere/udm-iptv/issues/167#issuecomment-1244797462) |
|   Telenor |   NO    | Yes                                                                                                                 |
|    PostTV |   LU    | [Manual configuration necessary](https://github.com/fabianishere/udm-iptv/discussions/86#discussioncomment-2345968) |
| Shanghai Telecom | CN | Yes, with an isolated IPTV routing table and VLAN 85 profile                                                      |

If your ISP is not supported, you may select the _Custom_ profile, which allows
you manually configure the package to your needs. 
We appreciate if you share the configuration so others can also benefit.
See the [profiles](profiles) directory for examples of existing configuration
profiles.

The package installs a service that is started during the
boot process of your UniFi device and that will set up the applications
necessary to route IPTV traffic. After installation, the service is automatically
started.

If you experience any issues while setting up the service, please visit the
[Troubleshooting](#troubleshooting) section.

### Installation across Firmware Updates

**Please remember to make a backup of your configuration before a
firmware update**. Currently, your configuration and installation might or might
not persist across firmware updates depending on the type of upgrade
(see [#120](https://github.com/fabianishere/udm-iptv/issues/120)).

### Configuration
You can modify the configuration of the service interactively as follows:
```bash
udm-iptv configure
```
See below for a reference of the available options to configure:

| Option                | Description                                                                                             |
|-----------------------|---------------------------------------------------------------------------------------------------------|
| IPTV_WAN_INTERFACE    | Interface on which IPTV traffic enters the router                                                       |
| IPTV_WAN_RANGES       | IP ranges from which the IPTV traffic originates (separated by spaces)                                  |
| IPTV_WAN_VLAN         | ID of VLAN which carries IPTV traffic (use 0 if no VLAN is used)                                        |
| IPTV_WAN_DHCP         | Boolean to indicate whether DHCP is enabled on the IPTV WAN (VLAN) interface                            |
| IPTV_WAN_DHCP_OPTIONS | [DHCP options](https://busybox.net/downloads/BusyBox.html#udhcpc) to send when requesting an IP address |
| IPTV_WAN_STATIC_IP    | Static IP address to assign to the IPTV WAN (VLAN) interface (if DHCP is disabled)                      |
| IPTV_WAN_MAC          | Custom MAC address to assign to the IPTV WAN VLAN interface                                             |
| IPTV_LAN_INTERFACES   | Interfaces on which IPTV should be made available                                                       |
| IPTV_ROUTE_TABLE      | Routing table for IPTV DHCP/static routes; use a dedicated numeric table on multi-WAN gateways          |
| IPTV_ROUTE_RULE_PRIORITY | Starting priority for policy rules that send IPTV LAN interfaces to the dedicated table              |
| IPTV_ALLOW_MAIN_DEFAULT_ROUTE | Explicit opt-in for an IPTV DHCP default route in the main table; defaults to `false`             |
| IPTV_NAT_ENABLE       | Enable source NAT towards the IPTV WAN                                                                  |
| IPTV_NAT_SOURCE_RANGES | Client source networks allowed to use IPTV NAT                                                         |
| IPTV_ALLOW_UNSCOPED_NAT | Explicit opt-in for destination-only NAT when WAN ranges include `0.0.0.0/0`; defaults to `false`     |
| IPTV_IGMPPROXY_DEBUG  | Enable debugging for igmpproxy                                                                          |
| IPTV_IGMPPROXY_DISABLE_QUICKLEAVE | Boolean to disables the quickleave feature for the IGMP Proxy. Set this to true if you have more than one IPTV decoder. Supported by both improxy and igmpproxy. |

The configuration is written to `/etc/udm-iptv.conf` (within UniFi OS).

### Isolated routing on multi-WAN gateways

Some IPTV DHCP servers advertise a default route. The original helper placed
that route in Linux's main table, which can take over Internet routing on a
UniFi gateway whose normal WANs are managed in separate policy tables.

Set `IPTV_ROUTE_TABLE` to a dedicated numeric table to isolate every DHCP and
manual IPTV route. The service then adds one policy rule for each interface in
`IPTV_LAN_INTERFACES`. A lookup that has no matching IPTV route falls through to
the normal UniFi routing policy; a DHCP default route remains usable only by
clients entering through the IPTV LAN interface.

The service also refuses two high-risk configurations by default:

* a DHCP default route in the main table; and
* `0.0.0.0/0` IPTV NAT without an explicit source subnet.

Run the non-mutating preflight before starting the service:

```bash
udm-iptv validate
```

### Shanghai Telecom on UCG Fiber

The bundled `Shanghai Telecom (CN, isolated routing)` profile targets this
topology:

* IPTV arrives as VLAN 85 on the selected UCG Fiber WAN port;
* IPTV viewers are attached to UniFi network `br85` (`192.168.85.0/24`);
* regular Internet uses independently managed primary and backup WANs.

Its safety-critical settings are equivalent to:

```bash
IPTV_WAN_VLAN="85"
IPTV_WAN_VLAN_INTERFACE="iptv"
IPTV_WAN_RANGES="0.0.0.0/0"
IPTV_WAN_DHCP_OPTIONS="-o -O subnet -O broadcast -O staticroutes"
IPTV_LAN_INTERFACES="br85"
IPTV_ROUTE_TABLE="185"
IPTV_ROUTE_RULE_PRIORITY="18500"
IPTV_ALLOW_MAIN_DEFAULT_ROUTE="false"
IPTV_NAT_ENABLE="true"
IPTV_NAT_SOURCE_RANGES="192.168.85.0/24"
IPTV_ALLOW_UNSCOPED_NAT="false"
```

Change the LAN interface and source subnet together if your UniFi IPTV network
does not use VLAN 85. Do not enable either safety escape hatch on a gateway
that also carries normal Internet traffic.

### Upgrading
Use the following command to upgrade `udm-iptv`:
```bash
udm-iptv upgrade
```
If that command does not exist, please re-run the installation script.

### Removal
To fully remove an `udm-iptv` installation from your UniFi device, run the follow command:
```bash
udm-iptv uninstall
```

## Troubleshooting

Below is a non-exhaustive list of issues that might occur while getting IPTV to
run on your UniFi device, as well as troubleshooting steps. Please check these
instructions before opening a discussion.

1. **Check if your IPTV receiver is on the right VLAN**  
   Your IPTV receiver might not be VLAN to which the IPTV traffic is forwarded.
2. **Check if IPTV traffic is forwarded to the right VLAN**  
   Make sure that you have configured `IPTV_LAN_INTERFACES` correctly to forward
   to right interfaces (e.g., `br4` for VLAN 4).
3. **If you have more than one IPTV decoder, disable the quickleave feature**
   Quickleave is enabled in the default configuration for improxy (the default IGMP proxy) and igmpproxy. If you have multiple IPTV decoders, quickleave will stop a stream for all decoders when just one decoder changes to a different stream.
4. **Check if your kernel supports multicast routing**  
   If `MRT_INIT failed; Errno(92): Protocol not available` appears in 
   diagnostics, your kernel does not support multicast routing.
5. **Check if your issue has been reported already**  
   Use the GitHub search functionality to check if your issue has already been
   reported before.

### Getting Help or Reporting an Issue
If your issues persist, you may seek help on our [Discussions](https://github.com/fabianishere/udm-iptv/discussions) page.
Please keep [GitHub Issues](https://github.com/fabianishere/udm-iptv/issues)
only for bugs or feature requests related to the project (no configuration-related issues).

When opening a discussion or reporting an issue, **please share the name of your
ISP as well as the diagnostics reported by our diagnostic tool**:
```bash
udm-iptv diagnose
```

## Contributing
Questions, suggestions and contributions are welcome and appreciated!
You can contribute in various meaningful ways:

* Report a bug through [GitHub issues](https://github.com/fabianishere/udm-iptv/issues).
* Contribute improvements to the documentation (e.g., configuration for other ISPs).
* Help answer questions on our [Discussions](https://github.com/fabianishere/udm-iptv/discussions) page.

## License
The code is released under the GPLv2 license. See [COPYING.txt](/COPYING.txt).
