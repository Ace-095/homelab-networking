# Sprint 3.5 — Security Hardening & Operational Reliability

**Objective:** not a new service — a deliberate pause to harden what already exists. Authentication, reboot persistence, automatic updates, and a proper look at how Docker actually interacts with the firewall.

## Starting point

Before this sprint: Ubuntu running headless, Docker + Compose + Portainer + Pi-hole all working, laptop and phone using Pi-hole for DNS, UFW enabled. Still open: SSH accepted passwords, Docker's firewall interaction was flagged but not investigated, automatic updates were unverified, and a leftover test container was still running.

## Docker vs. UFW, investigated properly

The bypass flagged back in Sprint 2 got a real investigation this time, instead of staying a documented-but-unexamined risk:

```bash
sudo iptables -L DOCKER-USER -n -v
sudo iptables -L DOCKER -n -v
sudo iptables -L FORWARD -n -v
sudo iptables -t nat -L -n -v
```

This confirmed the mechanism directly: Docker inserts its own `ACCEPT` rules into chains that get evaluated before UFW's `INPUT` chain even sees the traffic, so a published container port is reachable regardless of UFW policy. It also confirmed the fix path — **`DOCKER-USER`** is the one chain Docker guarantees it won't overwrite, making it the correct place for custom rules.

**Decision:** understand the mechanism now, implement the actual filtering in Sprint 4, rather than rushing a fix before it's fully understood. Consistent with the project's own rule — understand before implementing — but worth being precise about what this means in practice: until that filtering exists, Pi-hole and Portainer's published ports remain reachable from anything on the LAN, not just the two devices intentionally using them.

## Housekeeping

The temporary Nginx container from the Docker learning exercises in Sprint 2 was torn down (`docker compose down`), leaving only the two production services — Pi-hole and Portainer — running. Small step, but leftover test infrastructure is exactly the kind of thing that quietly becomes a forgotten, unpatched attack surface.

## Automatic security updates, verified

`unattended-upgrades` had been installed earlier but never actually confirmed active. This sprint checked for real:

```bash
systemctl status unattended-upgrades
```

Confirmed active and enabled, with `20auto-upgrades` and `50unattended-upgrades` configured correctly. This closes the gap flagged back in Sprint 1.

## SSH modernization

The largest piece of this sprint.

**1. Generated an Ed25519 key**, passphrase-protected:
```bash
ssh-keygen -t ed25519 -a 100
```
Ed25519 over RSA for a new key: shorter, faster, and considered the stronger modern default.

**2. Installed the public key** and verified the permissions that actually matter for SSH to trust them: `~/.ssh` at `700`, `authorized_keys` at `600`. Key-based login confirmed working.

**3. Disabled password authentication — and hit a real gotcha.** `PasswordAuthentication no` was set in the expected config file, but `sshd` kept reporting password auth was still active. Rather than assuming the edit just hadn't taken effect yet, the *effective* configuration was checked directly:

```bash
sshd -T | grep passwordauthentication
# passwordauthentication yes
```

Root cause: `/etc/ssh/sshd_config.d/50-cloud-init.conf` — a drop-in file that Ubuntu's cloud-init tooling creates — was setting `PasswordAuthentication yes` and loading *after* the manual edit, silently overriding it.

> **Lesson worth keeping:** editing a config file is not the same as confirming it took effect. `sshd -T` shows what the daemon is actually enforcing, not what any one file says. This applies well beyond SSH — anywhere configuration can be layered or overridden (cloud-init, drop-in `.d` directories, systemd unit overrides), check the effective state, not just the file you edited.

Once the override was corrected, password authentication was disabled and verified by forcing a password-only connection attempt:

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password acehomelab
# Permission denied (publickey)
```

Root login was disabled as well. Final state: Ed25519 keys only, no passwords, no root login.

## SSH convenience

An `~/.ssh/config` entry replaced `ssh ace@<server-ip>` with `ssh acehomelab`. `ssh-agent` (already running via GNOME Keyring on the client) confirmed the key was loaded, so the passphrase isn't re-entered every connection within a session.

## Reboot validation

The project's standing rule — everything must survive a reboot — was checked directly rather than assumed, and this time it meant re-verifying *every* previous fix at once, not just "did it turn back on":

| Check | Result |
|---|---|
| Docker service | Started automatically |
| Pi-hole & Portainer containers | Both started automatically |
| SSH | Connected immediately post-reboot via key auth, no password prompt |
| UFW | Active |
| `unattended-upgrades` | Active |
| Pi-hole dashboard | Reachable (see note below) |
| DNS chain | Confirmed via `resolvectl status` — local stub resolver correctly forwarding to Pi-hole |

One false alarm along the way: Pi-hole's root URL initially returned `403 Access Denied`, which looked like a break — it wasn't. Pi-hole v6 intentionally requires the `/admin` path; the dashboard loaded normally once that was used.

## Current security posture

- **SSH:** Ed25519 key-only, password auth disabled, root login disabled
- **Firewall:** UFW active, default deny incoming / allow outgoing (with the Docker caveat above still open)
- **Updates:** automatic security updates confirmed active
- **Containers:** Pi-hole and Portainer only — no leftover test services
- **Reliability:** every one of the above confirmed to survive a reboot, not assumed

## Known gaps / next actions

- **Docker/UFW filtering still isn't implemented** — the mechanism is now fully understood (see above), but the actual `DOCKER-USER` rules are Sprint 4 work, not done yet. Until then, Pi-hole and Portainer's ports are reachable LAN-wide.
- **Portainer's admin password** — worth confirming it's a strong, unique one now that HTTPS access is in place; carried over from Sprint 2/3.
- **`docker` group root-equivalence** — still just documented, not restricted beyond the single admin account.

## Lessons learned

- **A written config and an effective config are two different things.** Always verify with the tool designed to show you the truth (`sshd -T`), not by re-reading the file you just edited.
- **Cloud images carry their own defaults.** `cloud-init` drop-ins can silently override manual configuration on Ubuntu server — worth checking `/etc/ssh/sshd_config.d/` (and the equivalent `.d` pattern elsewhere) before assuming a setting "isn't working."
- **Reboot validation means re-checking everything, not just the newest change.** A single reboot is a chance to silently break several previously-fixed things at once — treat it as a full regression check, not a single pass/fail.
- **Understanding a security gap and closing it are different milestones.** Both are worth documenting, but only one of them actually reduces risk — say clearly which one you've done.
