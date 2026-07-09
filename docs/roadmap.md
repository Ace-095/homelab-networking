# Roadmap

## Sprint 2 — Infrastructure Platform ✅ Complete
Storage architecture finalized, group/SGID permissions, Ubuntu Pro, Docker Engine (official repo), Docker Compose, Portainer. Full writeup: [docs/02-docker-platform.md](02-docker-platform.md).

## Sprint 3 — Networking (in progress)
- **DNS fundamentals first** — recursive vs. authoritative resolution, root servers, caching/TTL, UDP vs. TCP for DNS, the full path of a query from laptop to internet.
- **Pi-hole** — deployed via Docker Compose. *Fix the Docker/UFW bypass (see Sprint 2 known gaps) before publishing port 53.*
- **Router integration** — point the network's devices at Pi-hole for DNS.
- **Local DNS** — friendly hostnames (`portainer.home`, `jellyfin.home`, `pihole.home`) instead of IPs.
- **Monitoring** — observe DNS traffic and understand how queries actually flow through the network.

## Sprint 4 — Remote Access
Tailscale, SSH key-based auth, disabling password authentication, core VPN concepts.

## Sprint 5 — Media Infrastructure
Jellyfin, SMB shares, media library organization, streaming.

## Sprint 6 — Monitoring
Uptime Kuma, Netdata, Prometheus, Grafana.

## Sprint 7 — Automation
Scheduled backups (3-2-1 rule in practice), cron jobs, update automation, health checks.

## Sprint 8 — Advanced Networking
Reverse proxy (Nginx Proxy Manager), HTTPS/certificates, internal DNS.

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
