# Sprint 7 — Remote Access with Tailscale

**Objective:** reach the HomeLab from outside the home network without opening a single port on the router.

## Why this approach instead of port forwarding

The conventional way to expose a home server is port forwarding plus either a static public IP or Dynamic DNS — which means the router accepts unsolicited inbound connections from the entire internet on whatever ports get opened. Tailscale takes a different approach entirely: it builds a private mesh VPN (over WireGuard) between only the devices you've explicitly authenticated to your account. The router's inbound policy never changes. Nothing is reachable from the open internet at any point in this setup.

## Setup

Tailscale was installed on the Ubuntu server directly (official install method, not Snap — consistent with how Docker itself was installed in Sprint 2), authenticated to the account, and joined the private tailnet. The Android phone was installed and authenticated the same way. Once both devices are on the same tailnet, they're mutually reachable peers regardless of what physical network either one is actually on.

## Two network identities on the same server

The server now answers on two separate interfaces:

```
ens32        → physical LAN interface, reachable only on the home network
tailscale0   → virtual VPN interface, reachable from anywhere, only by authenticated tailnet peers
```

The server's Tailscale address (in the `100.x.x.x` CGNAT range Tailscale uses internally — redacted here, not that it would be reachable by anyone outside the tailnet anyway) is a completely separate identity from its LAN IP. Connecting via `ssh acehomelab` locally and connecting via the Tailscale IP from outside the house hit the same machine through two different paths.

## The firewall gap this immediately exposed

SSH worked over Tailscale right away — but every Docker service (Homepage, Portainer, Pi-hole, Jellyfin) did not. This is a direct, predictable consequence of the `DOCKER-USER` policy built in Sprint 4: those rules were written to trust traffic arriving on `ens32` (the physical LAN), and said nothing about `tailscale0`. Packets were arriving at the server correctly — Tailscale itself worked — but getting silently dropped before ever reaching a container, for exactly the same reason unlisted LAN traffic gets dropped: default-deny doesn't make exceptions for good intentions.

## Fix: trust the tailscale0 interface

A rule was added to `DOCKER-USER` to accept forwarded traffic arriving via `tailscale0` and allow it through to the Docker containers. In plain terms: *if it's coming from the VPN interface, let it reach the containers.*

**Worth being explicit about the security model shift this represents.** The LAN-facing rules from Sprint 4 are deliberately narrow — per service, per device (laptop can reach Portainer, phone can reach Pi-hole, etc.). The `tailscale0` rule as described is broader: it trusts the *interface* as a whole, not individual services or devices reaching it. That's a defensible choice — only devices that have already been authenticated onto the tailnet can send traffic on that interface at all, so Tailscale's own auth is effectively doing the access control Sprint 4 was doing with per-rule LAN restrictions. But it's a different model, and worth documenting as a conscious decision rather than something that just happened to work — if tighter parity with the LAN policy is wanted later, the same per-service pattern from Sprint 4 could be applied to `tailscale0` too instead of trusting the whole interface.

## Made persistent

The updated rule set was saved with `netfilter-persistent`, same as Sprint 4, so it survives a reboot rather than needing to be re-applied by hand.

## Verified remotely (phone, off the home network)

- SSH — key-based auth, no password prompt, same as on the LAN
- Homepage
- Portainer
- Pi-hole Admin
- Jellyfin, including actual playback

## Concepts learned

- **Overlay networks** — a VPN like Tailscale runs *on top of* the existing internet rather than replacing any part of the home network's own routing.
- **Mesh VPN vs. traditional VPN server** — every authenticated device is a peer that can reach every other peer directly, rather than all traffic routing through one central VPN server.
- **A new network interface needs its own firewall consideration.** Adding an interface doesn't inherit the trust rules written for a different one — this is the same lesson as the DNAT port mismatch in Sprint 4, just at the interface layer instead of the port layer: *what you built the rule for and what's actually arriving can silently diverge.*

## Known gaps / next actions

- **Reboot validation for the `tailscale0` rule specifically** — `netfilter-persistent save` was run, but per this project's own standard (see Sprint 3.5 and Sprint 4), that's "saved," not "verified." Reboot and re-check that Tailscale reconnects automatically and Docker services are still reachable over it afterward.
- **Consider whether per-service rules on `tailscale0` are worth adding later**, rather than trusting the whole interface — not urgent given Tailscale's own device authentication, but worth a deliberate yes/no rather than leaving it implicit.
- **Carried over, still open:** `docker` group root-equivalence, Portainer's admin password, no fallback DNS resolver on clients.
