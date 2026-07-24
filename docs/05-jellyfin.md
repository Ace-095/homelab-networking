# Sprint 5 — Jellyfin (Media Streaming)

**Objective:** turn the HomeLab into a centralized media library instead of duplicating files across every device, and understand how a media server actually interacts with Docker and the host filesystem along the way.

## Deployment

Jellyfin runs as a Docker container, managed through Compose like every other service on this project. Configuration, metadata, and cache persist through mounted volumes, so recreating the container doesn't lose any state.

## Storage: bind mount, not a Docker volume

The media library lives at `/srv/data/media` — the directory structure already established back in Sprint 1 — and is **bind-mounted** directly into the container rather than copied into a Docker-managed volume:

```
Linux host
└── /srv/data/media
        │  (bind mount)
        ▼
Jellyfin container
└── /media
```

The distinction matters: a bind mount exposes an existing host path as-is, so Linux stays the actual source of truth for the files and Jellyfin never "owns" them. That means no duplicated media, simpler backups, and the container itself stays fully disposable — delete and recreate it any time without touching the actual files.

## Library setup

Once running, libraries were pointed at the mounted media directories. Jellyfin scans each one, pulls metadata and artwork from external providers, and builds its own searchable index — this is where the "movies just show up with posters and info" experience actually comes from.

## Performance: Direct Play over transcoding

Given the hardware this project runs on (Core2 Duo, no dedicated GPU), server-side transcoding was deliberately avoided in favor of **Direct Play** — letting client devices decode media themselves rather than asking this CPU to re-encode video in real time. This is a hardware-aware design decision, not a default: transcoding would almost certainly overwhelm this specific machine, so the architecture was chosen around the hardware that actually exists rather than Jellyfin's defaults.

## Troubleshooting

Media initially failed to display correctly. Rather than changing settings at random, each layer was checked independently — container status, the bind mount itself, Linux permissions and ownership on the media directory, the actual mounted path, and the Compose configuration — before rescanning the library.

**The specific root cause isn't documented yet** — this section will get filled in once that's confirmed (see Known gaps). Recording *what was actually wrong*, not just the checklist used to find it, is what makes a troubleshooting section useful to a future reader (including future-you).

## Verification

- Container starts and stays running
- Web interface reachable
- Libraries created, movies indexed with metadata
- Playback confirmed on client devices
- Configuration survives a container recreation

## Known gaps / next actions

- **The actual root cause of the media-detection issue isn't recorded.** Was it a bind mount path mismatch, a `PUID`/`PGID` permissions issue (same category as the Homepage deployment in Sprint 4), or something else? Worth adding once confirmed — an unresolved-looking troubleshooting section undercuts the value of documenting the process at all.
- **No `DOCKER-USER` firewall rule for Jellyfin is documented.** Every other service (Portainer, Pi-hole, Homepage) got an explicit rule in Sprint 4 under a default-deny policy. If Jellyfin is reachable from the LAN, there should be a corresponding rule — worth confirming what it allows and adding it to the Sprint 4 rule set for consistency.
- **Reboot validation isn't mentioned for this sprint** — worth confirming Jellyfin, its libraries, and playback all still work after a restart, consistent with every prior sprint's standard.
