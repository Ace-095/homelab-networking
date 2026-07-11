# Sprint 3 — DNS Infrastructure (Pi-hole)

**Objective:** turn the server from something that only hosts containers into something the network actually depends on — its DNS resolver — while understanding DNS deeply enough to do it safely.

## Before touching anything: how DNS currently worked

Rather than installing Pi-hole first and figuring out DNS later, the existing resolution path was inspected:

```bash
cat /etc/resolv.conf
# nameserver 127.0.0.53
```

That address isn't the router — it's `systemd-resolved`'s local stub listener. Applications don't talk to the router directly; they query `127.0.0.53`, and `systemd-resolved` forwards the request upstream. Confirmed the real upstream with:

```bash
resolvectl status
networkctl status ens32
# DNS Server: <router IP — redacted, see Sprint 0>
```

So the actual chain was `app → 127.0.0.53 (stub) → router → ISP`. Worth knowing before changing anything.

## Planning the rollout before doing it

Rather than pointing the router at Pi-hole immediately, a staged rollout was planned: prove Pi-hole works in isolation, then move one client over, then a second, and only then consider the whole network. This is the same "one change, one verification" principle from Sprint 0, applied to something with much higher blast radius — a DNS misconfiguration doesn't just affect one service, it affects every device that relies on it.

## Deploying Pi-hole

Same pattern as every other service so far — its own directory under the Compose layout, with persistent volumes:

```
/opt/homelab/compose/pihole/compose.yaml
```

`docker compose up -d` immediately failed: **`failed to bind port 53`**.

### Diagnosing the port conflict

```bash
ss -tulpn
lsof -i :53
```

Both pointed to the same thing: `systemd-resolved` already owned port 53 via its stub listener. Only one process can bind a port — so the stub listener had to go.

### Disabling the stub listener

```
/etc/systemd/resolved.conf
DNSStubListener=no
```

```bash
sudo systemctl restart systemd-resolved
```

**Unexpected consequence:** the server itself lost DNS resolution — there was no longer a local resolver at all. Fixed by pointing `/etc/resolv.conf` directly at the router temporarily, which restored connectivity while Pi-hole came up. *(Worth a follow-up check — see [Known gaps](#known-gaps--next-actions).)*

### A second, unrelated issue surfaced by the DNS change

`sudo` started warning `unable to resolve host acehomelab`. Root cause: a mismatch between the runtime hostname and `/etc/hosts`:

```
hostname        → acehomelab
/etc/hosts      → ace_homelab
```

Corrected the entry in `/etc/hosts` to match. Small thing, but a good example of one change surfacing an unrelated latent bug.

## Pi-hole comes up

```bash
docker compose ps   # healthy
docker logs pihole  # FTL started, database initialized, DNS + web server listening
```

Dashboard reachable and confirmed working (query log, stats, settings all populated).

## Docker networking: host mode vs. bridge

Briefly tested `network_mode: host` for Pi-hole (no port mapping needed) but reverted to the default bridge network — host mode bypasses Docker's network isolation entirely, which is unnecessary risk for what Pi-hole actually needs. Confirmed via `docker inspect` that it's back on `pihole_default`, a normal bridge network.

## Proving Pi-hole works before touching client config again

Instead of repeatedly reassigning a client's DNS settings to test, Pi-hole was queried directly:

```bash
dig @<pihole-ip> google.com        # status: NOERROR
nslookup google.com <pihole-ip>    # successful
```

This isolates the variable being tested — Pi-hole's resolution — without also depending on a client's network config being correct.

## IPv6: found, understood, deliberately postponed

Pi-hole's logs showed repeated failures reaching `2606:4700:4700::1111` (Cloudflare's IPv6 resolver) — the Docker bridge network has no IPv6 routing configured. Rather than patching this without understanding it, IPv6 was explicitly deferred to a dedicated future sprint. Recognizing "I don't fully understand this yet" and scoping it out is the same judgment call as the LUKS decision back in Sprint 0 — not every gap needs to be closed immediately, but every gap needs to be *written down*.

## Client integration

With Pi-hole proven in isolation, real devices were migrated one at a time:

1. **Laptop** — DNS pointed at the Pi-hole host. Verified with `resolvectl status`, `nslookup google.com`, and `dig google.com`. Pi-hole's dashboard confirmed the laptop as an active client.
2. **Phone** (on Wi-Fi) — same DNS server, same result: browsing worked, queries showed up in Pi-hole's log, and the phone picked up the same block lists as the laptop automatically.

The router itself was **not** repointed yet — that's the last, highest-blast-radius step, intentionally saved for once both test clients have run against Pi-hole for a while without issues.

## What this actually means

This is the point where the HomeLab stopped being a machine you log into to run things, and became infrastructure other devices depend on. If Pi-hole is down, the laptop and phone lose DNS — that dependency is now real, and it changes what "done" means for this sprint (see known gaps below).

## Known gaps / next actions

- **The Docker/UFW bypass from Sprint 2 is still unresolved, and now more urgent.** Pi-hole's port 53 (and its admin UI) are published Docker ports — meaning they're reachable from the LAN regardless of UFW policy, for the same reason the Nginx test was in Sprint 2. This was flagged as a "fix before publishing port 53" item and doesn't appear to have been addressed yet. Worth doing before the router itself is repointed at Pi-hole.
- **No fallback DNS resolver configured on clients.** Right now, if the server is down, the laptop and phone lose DNS entirely — there's no secondary resolver configured. Worth deciding: a secondary DNS entry (e.g., 1.1.1.1) as a safety net, or accept the single point of failure until a second Pi-hole instance exists.
- **The DNS chain hasn't been verified across a reboot yet.** `/etc/resolv.conf` was hand-edited mid-sprint, and the hostname fix touched `/etc/hosts` — both are exactly the kind of change that can silently revert or misbehave after a restart. Given this project's own "reboot-proof by default" rule, this is worth confirming directly: reboot the server and re-run the `resolvectl status` / `dig @<pihole-ip>` checks afterward.
- **`docker` group root-equivalence and Portainer's admin password** — carried over from Sprint 2, still open.

## Lessons learned

- **DNS has a much bigger blast radius than a single container.** That's exactly why this sprint moved slower and more deliberately than Sprint 2 — one client at a time, direct queries before client reconfiguration, router left alone until proven safe.
- **A fix can create a second problem.** Disabling the stub listener solved the port conflict and broke local resolution; that's normal, not a sign something went wrong — the point is noticing it immediately instead of hours later.
- **"I don't understand this yet" is a valid reason to stop**, as long as it's written down and scheduled rather than quietly ignored.
