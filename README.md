# HomeLab: `acehomelab`

A from-scratch home server build on repurposed hardware, documented as a real infrastructure project rather than a pile of notes. The goal isn't to run services — it's to understand *why* each piece of infrastructure exists, *how* it works internally, and *how* the pieces fit together, one verified step at a time.

**Owner:** Ace-095
**Hostname:** `acehomelab`
**OS:** Ubuntu Server 20.04.6 LTS
**Status:** Sprint 0 through 7 complete ✅ — Sprint 8 (Monitoring) up next

---

## Philosophy

Every change in this project follows the same rules:

1. **Observe before changing.** Understand current state before touching anything.
2. **One change, one verification.** No stacking untested changes.
3. **Reboot-proof by default.** If it doesn't survive a reboot, it isn't done.
4. **No unnecessary software.** Every installed package earns its place.
5. **Infrastructure before applications.** The foundation gets built before anything runs on top of it.
6. **Understand before automating.**
7. **Every sprint gets documented.** Decisions, reasoning, and verification steps — not just commands.

---

## Hardware

| Component   | Spec                                      |
|-------------|--------------------------------------------|
| CPU         | Intel Core2 Duo E8400 @ 3.0GHz             |
| RAM         | 3 GB usable                                |
| Disk 1      | 250 GB HDD — OS, Docker, configs           |
| Disk 2      | 160 GB HDD — bulk/media storage (~9 yrs power-on time, treated as unreliable — see [Sprint 1](docs/01-storage-and-hardening.md#disk-health)) |
| Network     | Realtek RTL810xE, 100 Mbps                 |

This is old, low-spec hardware on purpose — the constraints force a real understanding of what each service actually costs in RAM/CPU/disk, rather than throwing hardware at problems.

---

## Architecture

![acehomelab architecture](docs/architecture.png)

Docker Engine, Portainer, Pi-hole, Homepage, Jellyfin, and Samba are all live and firewalled per-service on the LAN. Tailscale now provides remote access over an encrypted mesh VPN, with its own `DOCKER-USER` trust rule for the `tailscale0` interface. Monitoring is the one thing still ahead.

---

## Progress

| Sprint | Topic                          | Status         |
|--------|--------------------------------|----------------|
| 0      | OS install, SSH, networking, boot verification | ✅ Complete |
| 1      | Hardening, storage, persistent mounts | ✅ Complete |
| 2      | Docker Engine, Compose, networking, volumes, Portainer | ✅ Complete |
| 3      | Pi-hole, local DNS, ad-blocking | ✅ Complete |
| 4      | Homepage dashboard + DOCKER-USER firewall rules | ✅ Complete |
| 5      | Jellyfin — media streaming | ✅ Complete |
| 6      | Samba — network file sharing / NAS | ✅ Complete |
| 7      | Tailscale — remote access / VPN | ✅ Complete |
| 8      | Monitoring (Uptime Kuma, Netdata, Grafana) | 🔄 Up next |
| 6      | Jellyfin, SMB, media organization | ⏳ Planned |
| 7      | Monitoring (Uptime Kuma, Netdata, Prometheus, Grafana) | ⏳ Planned |
| 8      | Backups, cron automation, health checks | ⏳ Planned |
| 9      | Reverse proxy, HTTPS, internal DNS, dedicated IPv6 sprint | ⏳ Planned |

Detailed writeups for completed sprints live in [`docs/`](docs/):

- **[Sprint 0 — Foundation](docs/00-foundation.md)** — OS install decisions, boot fix, networking, SSH
- **[Sprint 1 — Storage & Hardening](docs/01-storage-and-hardening.md)** — firewall, disk health analysis, storage architecture, user strategy
- **[Sprint 2 — Docker Platform](docs/02-docker-platform.md)** — storage finalized, group permissions + SGID, Ubuntu Pro, Docker, Compose, Portainer
- **[Sprint 3 — DNS Infrastructure (Pi-hole)](docs/03-dns-pihole.md)** — DNS fundamentals, staged rollout, port 53 conflict, first real client devices
- **[Sprint 3.5 — Security Hardening](docs/03b-security-hardening.md)** — Docker/UFW investigated, SSH key-only auth, automatic updates, full reboot validation
- **[Sprint 4 — Homepage & Firewall](docs/04-homepage-and-firewall.md)** — Docker packet flow traced, per-service firewall policy, DOCKER-USER rules implemented
- **[Sprint 5 — Jellyfin](docs/05-jellyfin.md)** — media streaming, bind mounts, Direct Play over transcoding
- **[Sprint 6 — Samba](docs/06-samba.md)** — network file sharing, shared storage with Jellyfin, SMB hardening
- **[Sprint 7 — Tailscale](docs/07-tailscale.md)** — remote access via mesh VPN, DOCKER-USER trust for tailscale0
- **[Roadmap](docs/roadmap.md)** — Sprint 8+ plan and success criteria

---

## Key engineering decisions at a glance

| Decision | Choice | Why (short version) |
|---|---|---|
| OS | Ubuntu Server 20.04.6 LTS | Stability and documentation depth over bleeding-edge features on old hardware |
| Disk encryption | Disabled (no LUKS) | Server must auto-recover after power loss without a manual passphrase at boot |
| IP addressing | DHCP reservation, not static | Router is the single source of truth; survives OS reinstalls |
| Firewall | UFW, default deny incoming | Every service must explicitly earn a rule — nothing open by default |
| Storage | UUID-based fstab mounts | Device names (`/dev/sdX`) can shift on reboot; UUIDs don't |
| Docker data | Lives on Disk 1 (the reliable disk), not Disk 2 | Disk 2 has real wear (see below) — losing container configs/databases is worse than losing media |
| Users | One admin (`ace`) + role users (`media`, `backup`), apps run in containers | Avoids one-Linux-user-per-app sprawl |
| Shared directory permissions | Group ownership + SGID (`chmod 2775`) | New files auto-inherit the directory's group — no manual `chgrp` after every write |
| Docker installation | Docker's official repo, not `apt install docker.io` or Snap | Current version, no Snap sandboxing quirks when doing networking work later |
| DNS rollout | Pi-hole proven via direct queries first, then one client at a time (laptop → phone → router, last) | DNS has network-wide blast radius; router-wide change saved for last, after it's proven stable |
| SSH authentication | Ed25519 keys only, passwords and root login disabled | Removes the most common remote attack vector; verified with effective-config checks, not just the edited file |
| Security updates | `unattended-upgrades` confirmed active, not just installed | Installing a package isn't the same as confirming the service is running |
| Container firewall policy | Per-service, per-device rules in `DOCKER-USER` (not a blanket allow) | DNS needs the whole LAN; every admin UI doesn't — least privilege, not convenience |
| Media storage | Bind mount (`/srv/data/media`), not a Docker volume, shared by Jellyfin and Samba | Linux stays the source of truth; no duplicated files; either service can be recreated without touching the data |
| Remote access | Tailscale mesh VPN, `DOCKER-USER` trusts the whole `tailscale0` interface | No router ports opened; Tailscale's own device auth substitutes for the LAN's per-service restrictions on that interface |

---

## Known gaps / next actions

Documenting this honestly is part of the point:

- **Jellyfin's media-detection root cause isn't documented.** Sprint 5 describes the troubleshooting checklist but never states what was actually wrong — needs filling in.
- **Jellyfin's `DOCKER-USER` LAN rule isn't documented.** It's reachable, but no corresponding firewall rule is recorded the way Portainer/Pi-hole/Homepage's were in Sprint 4 — worth confirming what allows it through.
- **Samba's actual configuration isn't recorded** — the design and decisions are documented, but not the literal `smb.conf` shares or user-setup commands.
- **Reboot validation is unconfirmed for Sprints 5, 6, and 7** — Jellyfin, Samba, and the new `tailscale0` firewall rule specifically.
- **No fallback DNS resolver on clients.** If the server goes down, the laptop and phone currently lose DNS entirely — no secondary resolver is configured.
- **Portainer's admin password** — worth confirming it's strong and unique now that HTTPS access is in place.
- **`docker` group membership is root-equivalent** — anyone in it effectively controls the host. Documented, not yet restricted beyond the single admin account.

✅ *Resolved:* Ubuntu 20.04's standard support gap (Ubuntu Pro/ESM, Sprint 2) · `unattended-upgrades` confirmed active (Sprint 3.5) · SSH password authentication disabled in favor of Ed25519 keys, root login disabled (Sprint 3.5) · full reboot persistence validated for Sprints 0–4 · **Docker bypassing UFW on the LAN** — per-service `DOCKER-USER` rules implemented in Sprint 4, reboot-verified · Homepage's config correctly placed on Disk 1.

---

## Repository structure

```
homelab-networking/
├── README.md
└── docs/
    ├── 00-foundation.md
    ├── 01-storage-and-hardening.md
    ├── 02-docker-platform.md
    ├── 03-dns-pihole.md
    ├── 03b-security-hardening.md
    ├── 04-homepage-and-firewall.md
    ├── 05-jellyfin.md
    ├── 06-samba.md
    ├── 07-tailscale.md
    ├── architecture.png
    └── roadmap.md
```
