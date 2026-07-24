# Sprint 6 — Samba (Network File Sharing)

**Objective:** turn the server into a proper NAS — letting devices on the network read and write files directly — without creating a second, duplicate storage location alongside what Jellyfin already uses.

## What Samba actually does here

Samba implements the SMB protocol, which is how Windows, Android, and macOS devices natively browse and access network file shares. Rather than exposing the Linux filesystem directly, it sits in front of it: authenticating users, enforcing its own share-level permissions, and presenting selected directories as network shares. A dedicated Samba user was created specifically for this, separate from Linux login accounts — network file access and server login are intentionally different trust boundaries.

## Reusing the existing storage design

No new directories were created for this. Two shares were defined against the storage hierarchy that already existed:

- **Media** — the same `/srv/data/media` directory Jellyfin reads from
- **Shared** — general-purpose file exchange between devices

Because both Samba and Jellyfin point at the same underlying files, anything dropped into the Media share is immediately visible to Jellyfin — no copying, no sync step, no second copy of anything to keep consistent.

## Permissions

Directory ownership, group permissions, and Samba's create/directory masks were configured together so files uploaded over the network inherit sane permissions automatically, rather than needing manual fixes after the fact — the same principle as the SGID setup from Sprint 2, applied at the network-share layer instead of the local filesystem layer.

## Validation

- `testparm` — confirmed the Samba config has no syntax errors and exports only the intended shares
- `smbd` restarted and confirmed active via `systemctl`
- Client authentication tested and confirmed
- Read and write access verified from a client device
- Files added via Samba confirmed visible to Jellyfin without any extra steps

## Security hardening

A few defaults were deliberately turned off rather than left at whatever Samba ships with:

- **Printer sharing removed** — the spool subsystem and default printer shares were disabled; nothing here needs to share a printer, so there's no reason to leave that surface exposed
- **SMB1 disabled** — the protocol was pinned to SMB2 and newer. SMB1 is legacy and has known security weaknesses; modern clients don't need it
- **Firewall reviewed in context** — the home router's NAT means these shares aren't reachable from outside the LAN even though Samba listens on all local interfaces, but that's a router-level protection, not something Samba itself is enforcing

## Known gaps / next actions

- **No specific `smb.conf` content or exact commands are recorded** — this write-up captures the design and decisions, but not the literal configuration. Worth adding the actual share definitions and `smbpasswd`/user-setup commands used, both for reproducibility and because that's the kind of concrete detail that made every earlier sprint doc useful as a real reference.
- **Reboot validation isn't mentioned for this sprint** — worth confirming `smbd` starts automatically and shares are reachable after a restart, same standard as every other service.
- **Carried over, still open:** `docker` group root-equivalence, Portainer's admin password, no fallback DNS resolver on clients.
