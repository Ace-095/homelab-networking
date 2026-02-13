# HomeLab Networking

Building and documenting a real home networking lab using an old PC running Debian.  
The goal is to deeply understand networking fundamentals by implementing, testing, and debugging concepts on real hardware.

---

## Approach

This lab follows a systems-first methodology:

- Learn fundamentals before tools
- Implement concepts incrementally
- Test after every change
- Debug using the OSI model (Layer 1 → Layer 7)
- Prefer understanding over convenience
- Keep everything reproducible

---

##  Current Infrastructure

- Old PC running Debian (headless)
- Ethernet LAN connection
- Static IP configured
- SSH access enabled
- Auto power-on after power loss

---

##  Topics Being Explored

- OSI model in practice
- ARP and MAC address resolution
- Static vs Dynamic IP
- Routing and gateways
- NAT behavior in home routers
- DNS resolution experiments
- Firewall basics
- Layer-by-layer debugging

---

## 📂 Repository Structure
architecture/ → Network diagrams and IP planning
fundamentals/ → Concept experiments (ARP, NAT, DNS, etc.)
implementations/ → Real configuration steps performed on server
debugging/ → Failure cases and OSI-based troubleshooting
configs/ → Example configuration files (sanitized)
