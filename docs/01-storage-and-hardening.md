# Sprint 1 — Storage & Hardening

**Objective:** harden the base install and build a storage architecture that's honest about the hardware's actual reliability.

## Firewall

**Technology:** UFW (Uncomplicated Firewall)

**Default policy:**
```
deny incoming
allow outgoing
```

**Explicitly allowed:** OpenSSH (22)

**Reasoning:** default-deny means every future service has to explicitly earn a firewall rule. Nothing is reachable by accident. This is the opposite of the common beginner pattern of opening ports as needed and never revisiting them — starting closed and adding rules one at a time keeps the attack surface auditable at every point.

---

## Disk health

Before deciding what Disk 2 (160 GB HDD) should be used for, it was checked with SMART — and not just the pass/fail summary, which hides more than it tells you.

| SMART attribute | Value | What it means |
|---|---|---|
| SMART overall status | PASSED | Necessary, but not sufficient — see below |
| Power-on hours | 78,729 (~9 years) | A long service life for a mechanical drive |
| Reallocated sectors | 20 | The drive has already retired 20 damaged sectors in favor of spares — some wear is normal, but it's a signal, not nothing |
| Reported uncorrectable errors | 12,651 | A large number of read/write errors the drive couldn't immediately correct on its own |
| ATA error history | 25,752 | A long history of hardware-level errors |

**Conclusion:** this disk is fine for data you can afford to lose or re-download — media, downloads, temporary files, ISOs — and not appropriate for anything irreplaceable: databases, personal documents, backups, or VMs.

This distinction — *replaceable* vs. *irreplaceable* data — is what drove the storage layout below, including keeping Docker's own data off this disk (see [Why Docker's data lives on Disk 1](#why-dockers-data-lives-on-disk-1)).

---

## Storage architecture

Disk 2's old NTFS partitions were removed and the disk was converted to GPT. It was then formatted and mounted:

```
Filesystem:  ext4
Label:       homelab-data
Mount point: /srv/data
```

**Mounted by UUID, not by device path.** `/etc/fstab` references the filesystem's UUID rather than `/dev/sdb1`. Device names can shift between boots depending on enumeration order; a UUID is stable for the life of the filesystem. This is a small detail that causes real outages when skipped.

**Verification performed:**
```bash
mount -a
df -h
mount | grep srv
```
...and confirmed again after a full reboot — the mount persists without manual intervention.

### Planned directory layout under `/srv/data`

```
/srv/data
├── media/
│   ├── movies/
│   ├── tv/
│   ├── music/
│   └── photos/
├── docker/
├── backups/
├── downloads/
├── shared/
├── projects/
└── archive/
```

---

## Why Docker's data lives on Disk 1

It would be easy to assume Docker itself, its images, and its containers' data should all live on the big secondary disk. That's a mistake worth avoiding.

Docker keeps two categories of data separate:

1. **Container images** — the application itself (small, replaceable — a `docker pull` away)
2. **Volumes / bind mounts** — the actual data a container reads and writes

A media server like Jellyfin is a good example: the Jellyfin image itself is roughly 500 MB, while the media library it serves might be 500 GB. Those two things have very different reliability requirements, and Docker lets them live on different disks:

```
Jellyfin container ──► /media (inside container)
                              │
                              ▼
                    bind-mounted to /srv/data/media
                              │
                              ▼
                          Disk 2
```

The container itself, and small but important state — Pi-hole's database, Portainer's config, Grafana's dashboards, Prometheus's metrics — stay on **Disk 1**. If Disk 2 fails, the worst case is losing media that can be re-acquired. If that same important container state were sitting on Disk 2 instead, a disk failure would mean every service silently forgets its configuration even though the server itself still boots.

**Resulting split:**

| Disk 1 (reliable) | Disk 2 (old, treated as expendable) |
|---|---|
| Ubuntu, Docker Engine | Movies, TV, music |
| Container images, Compose files | Downloads, ISOs |
| Configs, databases (Pi-hole, Portainer, Grafana) | Temporary files |
| SSH, firewall config | — |

This isn't a permanent architecture — once the 160 GB HDD is replaced with an SSD or proper NAS storage, this split gets revisited. Infrastructure evolves; a fixed hardware constraint today doesn't mean a fixed design forever.

A related idea, to be covered properly once the backup sprint (Sprint 7) arrives: the **3-2-1 backup rule** (3 copies of important data, on 2 different media, with 1 copy off-site), and why RAID — which isn't used here — is not a substitute for backups.

---

## User strategy

Rather than one Linux user per application (`plex`, `jellyfin`, `docker`, ...), this project uses:

- **`ace`** — the administrator account
- **`media`** — owns media files
- **`backup`** — owns backup data

Applications themselves run as containers, not as system users — so container sprawl doesn't turn into Linux-user sprawl.

---

## Lessons learned

- **A SMART "PASSED" is a starting point, not a conclusion.** Power-on hours, reallocated sectors, and error history tell the real story.
- **Separate data by consequence of loss, not just by type.** The question isn't "is this media or documents" — it's "if this disk dies today, what actually happens."
- **UUID mounts are non-negotiable for anything persistent.**
- **Firewall policy: start at deny, add exceptions one at a time** — never the reverse.
