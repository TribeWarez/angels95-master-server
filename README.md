# ANGELS95 — Master Server & Dedicated Server Hosting

Dedicated hosting infrastructure for [ANGELS95](https://github.com/odelyzid/angels-95-omega-tech) by TribeWarez: the `AngelMaster` listing server plus per-gamemode `AngelServ` dedicated test servers.

## Components

| Service | Binary | Ports | Gamemode |
|---|---|---|---|
| `angels95-master-api` | `AngelMaster` | `27900/udp`, `27950/tcp` | Master / listing server |
| `angels95-test-server` | `AngelServ` | `27015/udp`, `8080` | Plain co-op (default) |
| `angels95-test-coop` | `AngelServ` | `27016/udp`, `8081` | COOP campaign arc (`--campaign`) |
| `angels95-test-dm` | `AngelServ` | `27017/udp`, `8082` | Deathmatch (Etheral Match) |
| `angels95-test-tdm` | `AngelServ` | `27018/udp`, `8083` | Team Deathmatch (Angel Team Game) |

The `AngelMaster` / `AngelServ` binaries are fetched at build time from the upstream GitHub releases (see the `ANGELS95_TAG` build arg in each Dockerfile). No game source is vendored here.

## Gamemode selection

AngelServ has no per-mode CLI flag except `--campaign`; Deathmatch / TDM are driven by the **world's `levelinfo`** line in `World.ozone`. This repo ships authored mode worlds under `angels95-test-server/mode-worlds/` — Dust_Ravine copies with `levelinfo 2` (Deathmatch) and `levelinfo 3` (Team Deathmatch), `friendlyFire` on — bind-mounted over `/app/GameData/Worlds` per server so each dedicated server loads exactly one deterministic world.

## Run

```bash
docker compose -f docker-compose.angels95.yml build
docker compose -f docker-compose.angels95.yml up -d
```

All dedicated servers use `network_mode: host` so master heartbeats originate from the public interface (the master's anti-spoof rule ignores a self-reported `--public-ip` from a private source). Point the master target at the VPS public IP (`--master` / `--master-http` / `--public-ip`).

## Auto-update

`scripts/angels95-update.sh` polls the upstream `angels-95-omega-tech` releases and rebuilds/recreates the master + dedicated servers when a new tag is published. Run it from cron:

```bash
*/5 * * * * /path/to/angels95-master-server/scripts/angels95-update.sh
```

## Known limits (upstream)

- AngelMaster rate-limits heartbeats to 1 per 1.5s per source IP, so multiple servers behind one public IP may not all appear in `/api/servers` at once.
- The `AngelServ` binary self-reports a stale build string (`b58`); the release tag is authoritative.
- TDM has no team-aware friendly-fire gate yet (`friendlyFire=1` is treated as all-vs-all).
