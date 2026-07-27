# Sprint 8 — Monitoring Foundation (Uptime Kuma, Node Exporter, cAdvisor, Prometheus)

**Objective:** move from "the server just runs services" to "the server can be observed" — deploy an availability-monitoring layer and a metrics-collection pipeline, and keep both isolated from the rest of the network by design, not by accident.

## Two different questions

Before deploying anything, it's worth being explicit that "monitoring" actually means two separate concerns here:

| Tool | Question it answers | Example output |
|---|---|---|
| Uptime Kuma | *Is the service up right now?* | `UP` / `DOWN` |
| Prometheus (via Node Exporter / cAdvisor) | *How is it performing?* | `CPU = 40%`, `RAM = 900 MB` |

Both are needed — availability and performance are different failure modes, and conflating them into one tool would hide one or the other.

## Uptime Kuma

Deployed via Compose, same pattern as every other service: persistent storage, `restart: unless-stopped`, its own network. Admin account created, dashboard configured.

Monitors were added for the services that already exist: Homepage, Jellyfin, Pi-hole, Portainer. Each is a simple periodic HTTP check:

```
every N seconds → request → response? → UP
                                 no      → DOWN
```

## An isolated network for monitoring

Rather than attaching the monitoring stack to the same networks as user-facing services, a dedicated Docker network was created up front:

```bash
docker network create \
    --driver bridge \
    --internal \
    homelab-monitoring
```

The `--internal` flag means containers on this network can reach each other but **cannot reach the internet**. Node Exporter, cAdvisor, Prometheus, Uptime Kuma, and Grafana were all attached to it. This is the same "least privilege by default" principle as the `DOCKER-USER` firewall work in Sprint 4 — monitoring traffic has no reason to touch user-facing networks or the outside world, so it's structurally prevented from doing either, rather than just not doing it today. (The internet-access consequence of this choice shows up directly in Sprint 9.)

Resulting layout:

```
Docker Host
     │
     ├── Default bridge / per-service networks (unchanged from Sprint 4)
     │     Homepage · Jellyfin · Pi-hole · Portainer
     │
     └── homelab-monitoring (internal, no internet)
           Node Exporter · cAdvisor · Prometheus · Uptime Kuma · Grafana
```

Containers on `homelab-monitoring` address each other by Docker's built-in DNS rather than IPs — `prometheus`, `cadvisor`, `node-exporter` resolve automatically, the same mechanism every other Compose project on this host already relies on.

## Node Exporter

**Purpose:** expose *host*-level metrics — CPU, memory, disk, filesystems, load average, network, uptime.

The host's root filesystem is bind-mounted into the container (`--path.rootfs=/host`) so Node Exporter can inspect the real machine rather than only its own container namespace.

**Verified:**
```bash
docker exec uptime-kuma curl http://node-exporter:9100/metrics
```
Metrics returned successfully.

## cAdvisor

**Purpose:** expose *container*-level metrics — per-container CPU, memory, network, filesystem I/O, image/Compose metadata. This is the complement to Node Exporter: one describes the machine, the other describes what's running on it.

Requires mounts into `/`, `/var/run`, `/sys`, `/var/lib/docker`, and `/dev/kmsg` to actually observe running containers.

**Verified:**
```bash
docker exec uptime-kuma curl http://cadvisor:8080/metrics
```
Large metrics payload returned successfully.

## Prometheus

**Purpose:** scrape, store, and answer queries against metrics. Prometheus does **not** visualize anything — that's Grafana's job, deferred to Sprint 9.

Scrape config: 15-second interval, targets `node-exporter:9100` and `cadvisor:8080`. Attached only to `homelab-monitoring`, so it isn't reachable from the LAN at all.

**Verified:** Prometheus's own target status page confirmed both scrape targets healthy.

## Verification performed

Deploy → verify → understand → continue, same standard as every prior sprint:

- Node Exporter metrics reachable from inside the monitoring network
- cAdvisor metrics reachable from inside the monitoring network
- Prometheus targets both showing as `UP`
- Uptime Kuma monitors correctly reporting status for Homepage, Jellyfin, Pi-hole, Portainer

## Known gaps / next actions

- **No `DOCKER-USER` rule is documented for the monitoring stack's own dashboards.** Uptime Kuma and Grafana still need a web UI reachable from *something* (at minimum the laptop) — the same per-service, per-device pattern from Sprint 4 needs to be extended to these ports. Right now this isn't recorded, which means it's either undocumented-but-open or accidentally still unreachable; needs confirming either way.
- **Reboot validation hasn't been performed for the monitoring stack.** Every earlier service on this project has been explicitly reboot-tested (Sprints 0, 3.5, 4); Uptime Kuma, Node Exporter, cAdvisor, and Prometheus have not yet gone through that check.
- **Carried over, still open:** `docker` group root-equivalence, Portainer's admin password, no fallback DNS resolver on clients.

## Lessons learned

- **Availability and performance are different questions, worth different tools.** Uptime Kuma answers "is it up"; Prometheus answers "how is it doing." Neither replaces the other.
- **Isolate the monitoring network before you need to, not after an incident.** The `--internal` flag was a deliberate design choice made before any dashboard was even deployed — and it had a real, non-obvious consequence, covered in full in Sprint 9.
- **Verify each layer independently.** Node Exporter and cAdvisor were each confirmed with a direct `curl` before trusting Prometheus to scrape them — the same "prove it in isolation before trusting the next layer" habit from the Pi-hole rollout in Sprint 3.
