# Sprint 9 — Grafana: Dashboards, Debugging, and Closing the Monitoring Stack

**Objective:** finish the monitoring layer started in Sprint 8 by connecting Grafana to Prometheus, importing working dashboards, and understanding — rather than working around — the one real problem this surfaced.

## Starting point

Grafana was already running and reachable, with the login screen loading correctly — confirming Docker networking, port mapping, and firewall rules were all fine going into this sprint. What hadn't happened yet was making it actually useful: no data source, no dashboards.

## Initial login and data source

Logged in with the default `admin` / `admin` credentials, which immediately forced a password change — Grafana enforces this, not an optional step.

Added Prometheus as a data source:

```
Connections → Data Sources → Prometheus
URL: http://prometheus:9090
```

Worth calling out explicitly: this URL is a Docker DNS service name, not `localhost` and not the host's LAN IP. Grafana and Prometheus talk to each other entirely inside `homelab-monitoring`, the internal network built in Sprint 8. `Save & Test` confirmed the connection immediately.

## First real problem: dashboard import failed

Tried the standard approach — import by community dashboard ID (`1860`, the well-known Node Exporter dashboard). Grafana returned `Gateway Timeout` instead of loading it.

### Diagnosing it properly instead of guessing

```bash
docker exec grafana getent hosts grafana.com
# 2600:1901:0:b3ea:: grafana.com
```
DNS resolution succeeded — so this wasn't a naming problem.

```bash
docker exec grafana ping -c 3 8.8.8.8
# 100% packet loss
```
No outbound connectivity at all, despite DNS working. That distinction mattered: it ruled out a resolver problem and pointed straight at network-layer isolation instead.

```bash
docker exec grafana cat /etc/resolv.conf
# nameserver 127.0.0.11
```
Docker's internal embedded resolver, functioning correctly — consistent with the DNS test above.

### Root cause

Grafana is attached to `homelab-monitoring`, the `--internal` network created in Sprint 8 specifically to keep monitoring traffic isolated. `--internal` doesn't just isolate monitoring from the LAN — it also blocks the monitoring stack's own outbound internet access, since "internal" means *no route out at all*, not just "no route in." Grafana could resolve `grafana.com` but had no path to actually reach it, which is exactly why the ID-based import timed out. This is a direct, expected consequence of a Sprint 8 design decision, not a misconfiguration.

## Decision: keep isolation, import manually

Two options existed: give Grafana a route to the internet (loses some of the isolation Sprint 8 was built around), or keep the network fully isolated and import dashboard JSON by hand. The isolated option was chosen — it matches how production environments typically treat a monitoring network, and it's consistent with this project's own default-deny posture (UFW in Sprint 1, `DOCKER-USER` in Sprint 4, the monitoring network itself in Sprint 8).

Downloaded `node-exporter-full.json` from Grafana's public dashboard repository outside the container, then imported the JSON directly through Grafana's UI. (The repository also lists a BSD variant and an older "full" revision — the current Linux-targeted one was the correct pick.)

## Result: Node Exporter dashboard

Imported successfully and populated immediately with live data: CPU, memory, disk, network, filesystem, uptime.

**Graphs were mostly empty except for the most recent data points** — expected, not a fault. Prometheus had only just started scraping; historical panels fill in naturally as more data accumulates over time.

## cAdvisor dashboard

Imported the same way. Populated with per-container data (Homepage, and others) — CPU, memory, image metadata, Compose labels. Some panels showed `No data`, which is expected: metrics like filesystem I/O or network throughput only appear once a container actually performs that kind of activity, not on a fixed schedule.

## Verified end-to-end pipeline

```
Linux kernel → Node Exporter ─┐
                               ├─→ Prometheus → Grafana → browser
Docker containers → cAdvisor ─┘
```

| Layer | Status |
|---|---|
| Grafana reachable, logged in, password changed | ✅ |
| Grafana → Prometheus data source | ✅ Connected |
| Prometheus scraping Node Exporter | ✅ |
| Prometheus scraping cAdvisor | ✅ |
| Node Exporter dashboard | ✅ Live data |
| cAdvisor dashboard | ✅ Live data (some panels pending activity) |

## Known gaps / next actions

- **Grafana's own internet isolation is permanent by design, not a temporary state.** Any future dashboard or plugin update will need the same manual-JSON workflow used here, unless that trade-off is deliberately revisited.
- **No `DOCKER-USER` rule documented for Grafana's own UI**, same open item carried from Sprint 8 — needs a per-device rule (at minimum, laptop) the same way Homepage and Portainer got one in Sprint 4.
- **Reboot validation for the full monitoring stack (Sprint 8 + 9) is still outstanding.**
- **Alerting hasn't been configured.** Grafana can generate alerts on top of Prometheus data; this sprint stopped at dashboards, not notifications.
- **Carried over, still open:** `docker` group root-equivalence, Portainer's admin password, no fallback DNS resolver on clients.

## Lessons learned

- **DNS resolution and network connectivity are different failure modes — test them separately.** `getent hosts` succeeding while `ping` failed completely is what actually pinpointed the cause; assuming "DNS is probably it" would have wasted time down the wrong path.
- **An isolation choice from a previous sprint can resurface as a "bug" in a later one.** The Gateway Timeout wasn't a new problem — it was Sprint 8's `--internal` decision showing up somewhere it hadn't been exercised yet. Understanding *why* prevents chasing a fix that would have quietly undone a deliberate security choice.
- **Empty graphs and "No data" panels aren't always incidents.** A monitoring stack that just started collecting data is *supposed* to look sparse — the failure mode worth worrying about is silence that persists, not silence on day one.
