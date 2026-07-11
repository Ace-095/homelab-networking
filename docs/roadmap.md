# Roadmap

## Sprint 2 — Infrastructure Platform ✅ Complete
Storage architecture finalized, group/SGID permissions, Ubuntu Pro, Docker Engine (official repo), Docker Compose, Portainer. Full writeup: [docs/02-docker-platform.md](02-docker-platform.md).

## Sprint 3 — Networking ✅ Complete
DNS fundamentals (stub resolver, upstream resolution), Pi-hole deployed via Compose, port 53 conflict resolved, staged rollout to real clients (laptop, then phone). Router-wide switch deliberately held back until proven stable. IPv6 investigated and consciously deferred. Full writeup: [docs/03-dns-pihole.md](03-dns-pihole.md).

## Sprint 3.5 — Security Hardening & Operational Reliability ✅ Complete
Docker/UFW interaction fully investigated (`DOCKER-USER` identified as the fix point, implementation deferred to Sprint 4), test containers cleaned up, automatic updates verified active, SSH moved to Ed25519 keys only with password and root login disabled, and full reboot persistence validated across every service. Full writeup: [docs/03b-security-hardening.md](03b-security-hardening.md).

## Sprint 4 — Homepage Dashboard + Docker/UFW Filtering (up next)
A single landing page for every self-hosted service, plus finally implementing the `DOCKER-USER` firewall rules identified in Sprint 3.5 so published container ports actually respect network-level restrictions.

## Sprint 5 — Remote Access
Tailscale and core VPN concepts. (SSH key-based auth and password login already handled in Sprint 3.5.)

## Sprint 6 — Media Infrastructure
Jellyfin, SMB shares, media library organization, streaming.

## Sprint 7 — Monitoring
Uptime Kuma, Netdata, Prometheus, Grafana.

## Sprint 8 — Automation
Scheduled backups (3-2-1 rule in practice), cron jobs, update automation, health checks.

## Sprint 9 — Advanced Networking
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
