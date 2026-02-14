# Static IP Configuration on Debian

## Objective

Configure a static IP address for the Debian server to ensure consistent network identity and reliable SSH access.

---

## Why Static IP?

A static IP ensures:

- The server address does not change after reboot
- SSH access remains consistent
- Port-based services can be configured reliably
- The server can be referenced predictably within the LAN

---

## Initial Network State

(Dynamic IP via DHCP)

Command used to verify:
ip addr
ip route

# Static IP Configuration on Debian

## Objective

Assign a permanent IP address to the Debian server so it remains consistent after reboot.

---

## Initial State

The server was using DHCP.
IP was automatically assigned and could change.

Command used:
ip addr

Interface:
ens32

Subnet observed:
/24 (255.255.255.0)

---

## Network Observation

The LAN follows this structure:

192.168.X.Y/24

Where:
- First three octets represent the network
- Last octet represents the host

Only the last number changes between devices.

---

## Configuration Method

Modified file:
/etc/network/interfaces

Replaced DHCP configuration with:

auto ens32
iface ens32 inet static
    address 192.168.X.Z
    netmask 255.255.255.0
    gateway 192.168.X.1

---

## Address Notation Used in This Document

To avoid exposing real internal IP addresses, the following notation is used:

192.168.X.Z

Where:

- 192.168.X → Network portion of the LAN
- Z → Host portion manually selected for the server (static IP)

The value of Z represents the specific host address assigned to this Debian server.

## Testing

Restarted networking service.
Verified IP using:
ip addr

Pinged router to confirm connectivity.

Rebooted system.
Confirmed IP remained unchanged.

---

## What I Understood

- Static IP prevents IP changes after reboot.
- Netmask /24 means only last octet changes in this LAN.
- Gateway is required for communication outside subnet (to be explored deeper).


