# Sprint 0 — Foundation

**Objective:** build a stable Linux server that boots correctly, supports SSH, is remotely manageable, and survives a power cycle unattended.

## Installation decisions

**Operating system: Ubuntu Server 20.04.6 LTS.**
Chosen for stability, strong documentation, and lower risk on old hardware compared to a newer or less-tested release.

**LVM: enabled.**
Keeps the option open to expand or reorganize storage later without a reinstall, at no real cost during setup.

**LUKS full-disk encryption: disabled.**
A home server needs to come back up on its own after a power outage. LUKS requires a passphrase typed at boot, which makes unattended recovery impossible — the security benefit isn't worth losing auto-recovery for a box that isn't holding data that justifies at-rest disk encryption.

**OpenSSH server: installed at setup time.**
Needed from minute one, since the server is administered headless.

**Ubuntu Pro: skipped at install time.**
At the time, not needed for immediate HomeLab use. *(Revisit — see the "known gaps" note in the main README: standard support for 20.04 has since ended, and Ubuntu Pro's free tier is now worth enabling.)*

**Featured snaps: none installed.**
Every service will be installed manually so its internals are actually understood, rather than treated as a black box.

## Boot issue

**Problem:** after a full shutdown, the machine attempted a PXE network boot instead of booting into Ubuntu.

**Cause:** BIOS boot order wasn't pointing at the system disk first.

**Fix:** corrected the BIOS boot order.

**Verification:**
- Cold boot completes successfully
- Ubuntu boots automatically, no manual intervention
- SSH is reachable immediately after boot

## Networking

Ubuntu picked up an address via DHCP on interface `ens32`:

```
IP:      <redacted — private LAN address>
Gateway: <redacted — private LAN address>
```

> Actual addresses are omitted here since this doc is public. Both are private (RFC 1918) addresses, only meaningful on the local network.

### DHCP reservation, not a static IP on the host

Rather than hardcoding a static IP inside Ubuntu, the router was configured to always hand out the same private IP to this machine, keyed off its MAC address (both omitted here — no reason to publish either on a public repo).

Why this instead of a static config on the box itself:
- The router becomes the single source of truth for the network map
- Survives an OS reinstall with zero reconfiguration
- Avoids IP conflicts by construction
- Standard practice in real infrastructure — DHCP with reservations, not static host configs, unless there's a specific reason to deviate

## SSH

Installed during OS setup and verified working: remote login succeeds, and access survives a reboot.

## OS preparation

```bash
apt update
apt upgrade
apt autoremove
snap refresh
```

Baseline administration toolkit installed:

```
curl wget git vim nano htop tree zip unzip
net-tools dnsutils nmap software-properties-common bash-completion
```

The goal was a complete, familiar toolkit in place *before* any service installation begins — so troubleshooting later doesn't start with "wait, is `curl` even installed."

## Verification summary

| Check | Result |
|---|---|
| Cold boot | ✅ Boots to Ubuntu automatically |
| SSH after reboot | ✅ Reachable |
| DHCP reservation | ✅ Consistent IP across reboots |
| Base packages | ✅ Installed and confirmed |

## Lessons learned

- **DHCP reservation over static IP:** simpler to manage and more resilient to OS-level changes than it might first appear.
- **Fix boot order issues at the BIOS level, not around them.** A workaround (e.g., disabling PXE in the OS) would have masked a config problem rather than fixing it.
- **Understand first, automate later.** Nothing in Sprint 0 was scripted — every step was run and verified manually so the *why* is actually understood before it gets wrapped in automation in later sprints.
