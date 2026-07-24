# Sprint 4 — Homepage Dashboard & Docker/UFW Firewall

**Objective:** deploy a single dashboard for every self-hosted service, and finally close the Docker/UFW gap identified in Sprint 2 and investigated in Sprint 3.5 — not just understand it this time, implement it.

## Docker networks, inspected before touching anything

```bash
sudo docker network ls
```

Docker had already created a separate network per Compose project, rather than dropping everything onto the default bridge:

| Network | Subnet | Gateway | Notes |
|---|---|---|---|
| `bridge` (default, `docker0`) | 172.17.0.0/16 | 172.17.0.1 | Unused — nothing is attached to it |
| `portainer_default` | 172.19.0.0/16 | 172.19.0.1 | Portainer at 172.19.0.2 |
| `pihole_default` | 172.20.0.0/16 | 172.20.0.1 | Pi-hole at 172.20.0.2 |

Confirming the default bridge sits empty is a useful sanity check — it means every service really is isolated in its own Compose-managed network, not quietly sharing one flat network by accident.

## Linux interfaces, inspected

```bash
ip a
```

- **`ens32`** — the physical LAN interface (server's real IP, redacted here)
- **`docker0`** — Docker's default bridge (172.17.0.1), confirmed unused as above
- **User-defined bridges** (e.g. `br-380332400a93`, `br-b379cbb9e6ac`) — one per Compose project, acting as a virtual switch for that project's containers. The hex suffix is just Docker's own generated network ID, not anything meaningful on its own.
- **`veth` pairs** — virtual Ethernet cables, one end inside a container's network namespace, the other plugged into that project's bridge. This is the actual mechanism that gets a packet from "inside the container" to "on the bridge" in the first place.

## Packet flow, traced end to end

```
Laptop (<LAN IP, redacted>)
    │
Router
    │
Ubuntu Server (<LAN IP, redacted>)
    │
iptables NAT — DNAT
    │
Docker bridge
    │
172.20.0.2 (Pi-hole, container-internal address)
```

And the full chain a forwarded packet actually traverses:

```
PREROUTING → DNAT → FORWARD → DOCKER-USER → DOCKER-FORWARD → DOCKER → container
```

Commands used to inspect this directly, rather than taking it on faith:

```bash
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v
sudo iptables -L DOCKER
sudo iptables -L DOCKER-USER
sudo iptables -L FORWARD
sudo ufw status numbered
sysctl net.ipv4.ip_forward
```

The NAT table confirmed Docker's own DNAT rules, mapping host-published ports to container-internal ones:

| Published (host) | Rewritten to (container) |
|---|---|
| 9000 | Portainer |
| 9443 | Portainer HTTPS |
| 8081 | Pi-hole, port 80 |
| 53 | Pi-hole DNS |

The critical detail this makes clear: **DNAT happens before `DOCKER-USER` is ever evaluated.** By the time a packet reaches `DOCKER-USER`, its destination has already been rewritten from the host's published port to the container's internal port — which is exactly what caused the debugging issue below.

## Security design

An explicit, per-service access policy was defined instead of a single blanket rule:

| Service | Allowed devices |
|---|---|
| SSH | Handled by UFW directly |
| Portainer (9000 / 9443) | Laptop only |
| Pi-hole Admin (8081) | Laptop + Phone |
| Pi-hole DNS (53) | Entire LAN |
| Homepage (3000) | Laptop only |
| Everything else | Blocked |

DNS is intentionally open to the whole LAN because that's its job — every admin interface is restricted to the specific device(s) that actually need it. Least privilege, not just "firewall on."

## Implementing it: `DOCKER-USER` rules

Rules were added to the `DOCKER-USER` chain — the one chain Docker guarantees it won't overwrite on restart — rather than UFW, since UFW's rules are evaluated too late to matter for published container ports (confirmed back in Sprint 3.5):

- Allow laptop → Portainer
- Allow laptop → Portainer HTTPS
- Allow laptop → Pi-hole Admin
- Allow phone → Pi-hole Admin
- Allow entire LAN → DNS
- **Drop everything else** forwarded in via `ens32`

This is the piece that had been an open, documented risk since Sprint 2 — a real default-deny policy for Docker services, not just for the host itself.

## Making the rules survive a reboot

Firewall rules added by hand don't persist through a restart unless explicitly saved:

```bash
sudo netfilter-persistent save
sudo iptables-save   # used to confirm the rules were actually written to disk
```

## Debugging log

**1. `permission denied` connecting to `docker.sock`.** Standard Linux permissions issue — the shell session wasn't in the `docker` group (or wasn't using `sudo`). Worth repeating from Sprint 2: adding a user to the `docker` group is root-equivalent access to the host, not a harmless convenience.

**2. Pi-hole became unreachable from the phone after the firewall rule was applied.** Rather than guessing, `iptables`'s own packet counters were used to see what was actually happening: the phone's allow rule showed **0 matched packets**, while the DROP rule's counter kept climbing. That's what pointed at the real cause — the rule was written against the host-published port (8081), but DNAT had already rewritten the destination to the container's internal port (80) before the packet ever reached `DOCKER-USER`. Rewriting the rule to match port 80 instead of 8081 fixed it immediately, confirmed by watching the allow rule's counter start incrementing instead. **This is the single best lesson from the sprint: write `DOCKER-USER` rules against the container's internal port, always** — the host-published port only matters before DNAT runs.

**3. Homepage returned a host validation error.** Homepage checks the `Host` header of incoming requests against an allow-list as a security measure (protects against DNS-rebinding-style attacks). Since it was being accessed by IP rather than the hostname it expected, it rejected the request until the allowed hosts were explicitly configured to include the address being used to reach it.

**4. Homepage was unreachable immediately after deployment** for a much simpler reason than #3 first suggested: no `DOCKER-USER` rule existed yet for port 3000 at all. Added `Allow laptop → Homepage`, saved with `netfilter-persistent save`, and access worked as intended — laptop only.

## Deploying Homepage

```yaml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    ports:
      - "3000:3000"
    volumes:
      - ./config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      PUID: 1000
      PGID: 1001
    restart: unless-stopped
```

Worth calling out: the Docker socket is mounted **read-only** (`:ro`). Homepage needs to *see* running containers to build its dashboard, but doesn't need to control them — mounting read-only is a real, deliberate reduction of what a compromised Homepage container could do, versus the more common (and riskier) read-write socket mount.

Configuration is spread across a few YAML files — `services.yaml`, `bookmarks.yaml`, `widgets.yaml`, `docker.yaml` — with Docker integration enabled via:

```yaml
my-docker:
  socket: /var/run/docker.sock
```

The default demo content was replaced with the actual services (Homepage, Portainer, Pi-hole, the Ubuntu server) and a handful of real reference bookmarks (Docker docs, Homepage docs, Pi-hole docs, Docker Hub, GitHub, Ubuntu's own documentation).

## Current state

| Service | Port(s) | Access |
|---|---|---|
| Homepage | 3000 | Laptop only |
| Portainer | 9000 / 9443 | Laptop only |
| Pi-hole Admin | 8081 | Laptop + Phone |
| Pi-hole DNS | 53 | Entire LAN |

Default-deny for every Docker service: anything not explicitly listed above is dropped at `DOCKER-USER`.

## Known gaps / next actions

- **`docker` group root-equivalence** and **Portainer's admin password** — both still carried over, unresolved.
- **No fallback DNS resolver on clients** — still open from Sprint 3.

✅ *Resolved:* reboot validation completed — firewall rules, Homepage/Portainer/Pi-hole reachability, and the access policy above all confirmed to survive a restart. Homepage's config moved from `/srv/data` to `/opt/homelab/compose/homepage`, matching Portainer and Pi-hole on Disk 1.

## Lessons learned

- **DNAT happens before your custom firewall rules even see the packet.** Any `DOCKER-USER` rule aimed at a container has to target the internal container port, not the host-published one.
- **Packet counters are a debugging tool, not just a curiosity.** Watching which rule's counter actually increments is a faster way to find a firewall misconfiguration than re-reading the rule file.
- **A firewall policy is a table, not a toggle.** "UFW is on" was never actually the safety boundary here — a per-service, per-device policy is.
- **"Saved" and "verified" are different claims.** Writing a config to disk and confirming it survives a real reboot are two separate steps — don't call a sprint done on the first one alone.
