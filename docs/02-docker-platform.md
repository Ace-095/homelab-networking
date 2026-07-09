# Sprint 2 — Docker Platform

**Objective:** turn the hardened Ubuntu base into a real container platform, understanding each layer instead of installing software blindly. This session also closed out two carry-over items from Sprint 1: finalizing the storage split and enabling long-term OS support.

## Storage, finalized

Before touching Docker, the storage question from Sprint 1 was settled for real: Docker's own data — images, volumes, networks, the engine itself — needed to live on Disk 1, not Disk 2. This was verified rather than assumed, by inspecting `/var/lib/docker` directly and confirming its contents (`containers`, `overlay2`, `images`, `networks`, `volumes`) sit on the reliable disk.

```
Disk 1 (reliable)                 Disk 2 (data)
├── /                              /srv/data
├── /etc, /boot, /home, /var       ├── media
│    └── Docker Engine,            ├── downloads
│        images, volumes,          ├── archive
│        networks                  ├── shared
└── /opt/homelab                   ├── backups
                                    └── projects
```

If Disk 2 fails: Ubuntu still boots, SSH still works, Docker still runs, Portainer still works. Only media is lost — exactly the design intent from Sprint 1.

## Permission model: groups, not per-app users

Rather than fixing permissions ad hoc, a proper group-based model was set up:

```bash
# groups created
media
backupdata
shared

# admin added to each
sudo usermod -aG media,backupdata,shared ace
```

Shared directories (`/srv/data/media`, `/srv/data/backups`, `/srv/data/shared`) were given group ownership and the **SGID bit**:

```bash
sudo chgrp media /srv/data/media
sudo chmod 2775 /srv/data/media
```

SGID means every new file or folder created inside automatically inherits the parent directory's group, instead of defaulting to the creating user's primary group. A file dropped into `/srv/data/media` by `ace` is owned by `ace` but grouped `media` automatically — no manual `chgrp` afterward. Small mechanism, but it's what separates "permissions that work" from "permissions I have to keep fixing."

## Ubuntu Pro enabled

Ubuntu 20.04 LTS had fallen out of standard support (see Sprint 1's known gaps). That's now resolved:

```bash
sudo pro attach
sudo pro enable esm-infra esm-apps
```

The server now has Expanded Security Maintenance and Livepatch, with security coverage through 2030.

## Docker installation

Installed from **Docker's official repository**, not `apt install docker.io` or `snap install docker` — both lag behind and, in Snap's case, sandbox the daemon in ways that complicate later networking work. Installed: Docker Engine, the Docker CLI, `containerd`, Buildx, and the Compose plugin.

**`docker run hello-world`** — the standard sanity check, but worth actually watching what happens: image pulled → container created → container runs → container exits → image remains. That last part is the key distinction between an *image* (the static template) and a *container* (a running instance of it) — the container disappears, the image stays cached.

## First real service: Nginx

Published container port 80 to host port 8080 and confirmed the server responded. This is also where the most important lesson of the day showed up — see **Known gaps** below.

## Docker networking & filesystem, inspected

`docker inspect` on the running container showed:

```
Container IP: 172.17.0.2
Gateway:      172.17.0.1
Bridge:       docker0
```

Docker creates a bridge network, NAT, and port-forwarding automatically for every container — this is *why* a container with its own private IP is reachable through a host port at all. Confirmed separately that Docker's on-disk state (`/var/lib/docker/{containers,overlay2,images,networks,volumes}`) lives on Disk 1, matching the storage design above.

## Docker Compose adopted

Moved from ad hoc `docker run` commands to Compose files, one directory per service:

```
/opt/homelab/
├── compose/
│   ├── nginx/
│   │   ├── compose.yaml
│   │   └── html/index.html
│   └── portainer/
│       └── compose.yaml
└── scripts/
```

This is the shift from imperative commands to **infrastructure as code** — the compose file *is* the documentation of how a service is configured, and it's reproducible without remembering a chain of flags.

Also covered:
- **Bind mounts** — `/opt/homelab/compose/nginx/html` mapped straight into the container's web root; editing the file on the host changes what Nginx serves immediately, no need to enter the container.
- **`docker logs` / `docker logs -f`** — real HTTP requests visible as they arrive.
- **`restart: unless-stopped`** — set, then verified by actually rebooting the server. Docker, Compose, and Nginx all came back up unattended, consistent with this project's "reboot-proof by default" rule.
- **Named volumes vs. bind mounts** — a bind mount points at a specific host path you control; a named volume is managed by Docker itself. Different tools for different jobs.

## Portainer deployed

Deployed via its own Compose file, admin account created, local Docker environment connected. Containers, images, volumes, and networks are now all visible and manageable through a web UI rather than the CLI alone.

## Current architecture

![Architecture diagram](architecture.png)

## Known gaps / next actions

- **Docker silently bypasses UFW.** Docker writes its own rules directly into the iptables `FORWARD`/`DOCKER` chains, which are evaluated *before* UFW's rules (UFW only governs `INPUT`). The practical effect: any port a container publishes is reachable from the LAN regardless of UFW policy — `ufw deny <port>` does not stop it, and `ufw status` gives no indication anything is wrong. This needs a fix via the `DOCKER-USER` iptables chain (or the `ufw-docker` tool that automates it) **before** Pi-hole publishes port 53 or Portainer's UI is left running unattended.
- **`docker` group membership is root-equivalent.** Anyone in the `docker` group can control the Docker daemon, which runs as root — worth treating as a privileged group, not a convenience group.
- **Portainer's admin UI needs a strong password and, ideally, network-level restriction** once it's reachable — it has administrative control over every container on the host.
- **`unattended-upgrades` still isn't configured** (carried over from Sprint 1).

## Lessons learned

- **Verify architecture decisions instead of re-deciding them from scratch.** The Disk 1/Disk 2 split from Sprint 1 didn't need to be redesigned — it needed to be confirmed against what Docker actually does on disk.
- **A firewall you haven't tested against Docker isn't verified — it's assumed.** "Default deny" was true at the UFW layer and false at the network layer the moment a container published a port.
- **Groups + SGID scale better than fixing permissions per file.** Set the mechanism up once; stop thinking about it afterward.
