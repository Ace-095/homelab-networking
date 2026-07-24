# Roadmap

## Sprint 2 — Infrastructure Platform ✅ Complete
Storage architecture finalized, group/SGID permissions, Ubuntu Pro, Docker Engine (official repo), Docker Compose, Portainer. Full writeup: [docs/02-docker-platform.md](02-docker-platform.md).

## Sprint 3 — Networking ✅ Complete
DNS fundamentals (stub resolver, upstream resolution), Pi-hole deployed via Compose, port 53 conflict resolved, staged rollout to real clients (laptop, then phone). Router-wide switch deliberately held back until proven stable. IPv6 investigated and consciously deferred. Full writeup: [docs/03-dns-pihole.md](03-dns-pihole.md).

## Sprint 3.5 — Security Hardening & Operational Reliability ✅ Complete
Docker/UFW interaction fully investigated (`DOCKER-USER` identified as the fix point, implementation deferred to Sprint 4), test containers cleaned up, automatic updates verified active, SSH moved to Ed25519 keys only with password and root login disabled, and full reboot persistence validated across every service. Full writeup: [docs/03b-security-hardening.md](03b-security-hardening.md).

## Sprint 4 — Homepage Dashboard + Docker/UFW Filtering ✅ Complete
Docker packet flow traced end to end (PREROUTING → DNAT → FORWARD → DOCKER-USER → DOCKER-FORWARD → DOCKER), explicit per-service/per-device firewall policy defined and implemented via `DOCKER-USER` rules, rules persisted with `netfilter-persistent` and reboot-verified. Homepage deployed as a unified dashboard, its config correctly placed on Disk 1 alongside Portainer and Pi-hole. Closes the Docker/UFW gap open since Sprint 2. Full writeup: [docs/04-homepage-and-firewall.md](04-homepage-and-firewall.md).

## Sprint 5 — Jellyfin ✅ Complete
Media streaming via Docker, bind-mounted to `/srv/data/media` rather than a Docker volume, Direct Play chosen over transcoding for the current hardware. Full writeup: [docs/05-jellyfin.md](05-jellyfin.md).

## Sprint 6 — Samba ✅ Complete
Network file sharing (NAS) sharing the same storage as Jellyfin, dedicated Samba auth, SMB1 disabled, printer sharing removed. Full writeup: [docs/06-samba.md](06-samba.md).

## Sprint 7 — Tailscale ✅ Complete
Mesh VPN remote access with no router ports opened; surfaced and fixed a real firewall gap where the new `tailscale0` interface wasn't trusted by the Sprint 4 `DOCKER-USER` rules. Full writeup: [docs/07-tailscale.md](07-tailscale.md).

## Sprint 8 — Monitoring (up next)
Uptime Kuma, Netdata, Prometheus, Grafana.

## Sprint 9 — Automation
Scheduled backups (3-2-1 rule in practice), cron jobs, update automation, health checks.

## Sprint 10 — Advanced Networking
Reverse proxy (Nginx Proxy Manager), HTTPS/certificates, internal DNS, and a dedicated, in-depth IPv6 sprint (deferred from Sprint 3).

---

## Success criteria

This HomeLab is considered successful when it:

- Boots without any manual intervention
- Remains reachable over SSH at all times
- Has a clean, deliberate storage architecture
- Runs every service inside a container
- Reflects an actual understanding of the networking involved, not just copy-pasted configuration
- Is fully reproducible from this documentation
- Has every sprint tested and written up before moving to the next
