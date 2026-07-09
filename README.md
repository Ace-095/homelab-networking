# HomeLab: `acehomelab`

A from-scratch home server build on repurposed hardware, documented as a real infrastructure project rather than a pile of notes. The goal isn't to run services — it's to understand *why* each piece of infrastructure exists, *how* it works internally, and *how* the pieces fit together, one verified step at a time.

**Owner:** Ace-095
**Hostname:** `acehomelab`
**OS:** Ubuntu Server 20.04.6 LTS
**Status:** Sprint 0, 1 & 2 complete ✅ — Sprint 3 (Pi-hole / DNS) up next

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
/home/ace/PROJECTS/MAIN/ACEHOMELAB/homelab-networking/architecture.png
![acehomelab architecture](docs/architecture.png)

Docker Engine and Portainer are live as of Sprint 2. Pi-hole is being deployed now (Sprint 3); Tailscale, Jellyfin, Homepage, and the monitoring stack are still ahead.

---

## Progress

| Sprint | Topic                          | Status         |
|--------|--------------------------------|----------------|
| 0      | OS install, SSH, networking, boot verification | ✅ Complete |
| 1      | Hardening, storage, persistent mounts | ✅ Complete |
| 2      | Docker Engine, Compose, networking, volumes, Portainer | ✅ Complete |
| 3      | Pi-hole, local DNS, ad-blocking | 🔄 In progress |
| 4      | Tailscale, SSH key-only auth   | ⏳ Planned |
| 5      | Jellyfin, SMB, media organization | ⏳ Planned |
| 6      | Monitoring (Uptime Kuma, Netdata, Prometheus, Grafana) | ⏳ Planned |
| 7      | Backups, cron automation, health checks | ⏳ Planned |
| 8      | Reverse proxy, HTTPS, internal DNS | ⏳ Planned |

Detailed writeups for completed sprints live in [`docs/`](docs/):

- **[Sprint 0 — Foundation](docs/00-foundation.md)** — OS install decisions, boot fix, networking, SSH
- **[Sprint 1 — Storage & Hardening](docs/01-storage-and-hardening.md)** — firewall, disk health analysis, storage architecture, user strategy
- **[Sprint 2 — Docker Platform](docs/02-docker-platform.md)** — storage finalized, group permissions + SGID, Ubuntu Pro, Docker, Compose, Portainer
- **[Roadmap](docs/roadmap.md)** — Sprint 2–8 plan and success criteria

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

---

## Known gaps / next actions

Documenting this honestly is part of the point:

- **Docker bypasses UFW.** Docker writes its own iptables rules directly into the `FORWARD`/`DOCKER` chains, which are evaluated before UFW's (`INPUT`-only) rules — meaning any port a container publishes is reachable from the LAN regardless of UFW policy, and `ufw status` gives no warning that this is happening. Needs a `DOCKER-USER` chain fix (or the `ufw-docker` tool) before Pi-hole publishes port 53. See [Sprint 2](docs/02-docker-platform.md#known-gaps--next-actions).
- **`docker` group membership is root-equivalent** — anyone in it effectively controls the host. Documented, not yet restricted beyond the single admin account.
- **Portainer's admin UI** needs a strong password and ideally network-level restriction once it's routinely left running.
- **`unattended-upgrades` isn't configured yet** — security patches currently require manual `apt upgrade`.
- **SSH is still password-based** — key-only auth is scheduled for Sprint 4, but until then it's the weakest point in the current setup.

✅ *Resolved:* Ubuntu 20.04's standard support gap — Ubuntu Pro (free tier) enabled in Sprint 2, ESM active through 2030.

---

## Repository structure

```
homelab-networking/
├── README.md
└── docs/
    ├── 00-foundation.md
    ├── 01-storage-and-hardening.md
    ├── 02-docker-platform.md
    ├── architecture.png
    └── roadmap.md
```
