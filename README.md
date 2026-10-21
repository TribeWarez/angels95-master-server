# ANGELS95 — Master Server & Dedicated Server Hosting

Dedicated hosting infrastructure for [ANGELS95](https://github.com/TribeWarez/Angels-95) by TribeWarez: the `AngelMaster` listing server plus per-gamemode `AngelServ` dedicated test servers.

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

`--campaign` was added in b95; **b100 is the first complete release** that
contains it. b94's argument parser silently ignores unknown flags, so on the
old tag the COOP service is plain co-op. Even on b100+, `Dessert_Dreams` is not
a mission world, so the arc seeds nothing; point that service's `--dir` at a
`Sektor_*` mission world to exercise it.

## Versioning and the release pipeline

The images fetch the `ANGELS95_TAG` build arg (default **`b100`**). From b100 the
release tag is stamped into the binary (`Source/Version.hpp`), exposed by
`AngelServ --version`, reported as `gamever` in the heartbeat and `/status`,
and the wire-compatibility id is reported separately as `proto`
(`net::PROTOCOL_VERSION`). Older builds all claim `0.2.1` / `build b58`.

`scripts/angels95-update.sh` polls **`releases/latest`**, not tags. The history
matters for anyone reading an old list:

- b95/b96/b97 are git tags with **no GitHub Release** (CI `make test` failed;
  the game hierarchy was untracked).
- b98 has a **Windows-only** release: its Linux job failed at `miniz`
  (`ftello`/`fseeko` under `-std=c99`).
- b99 had all assets, but its `AngelServ` was built on the new `ubuntu-latest`
  (glibc 2.43) and required `GLIBC_2.43` for `sqrtf`/`atan2f`; the
  `ubuntu:24.04` images (glibc 2.39) killed every game-server container at
  exec. b99 is **not** safe to deploy.
- **b100 is the first release that runs in these images**: the Linux runner is
  pinned to `ubuntu-24.04` and CI fails if either binary requires GLIBC newer
  than 2.39. It is `releases/latest`, and the updater now has both Linux assets
  it requires.

A plain master rebuild never fixed the listing: the b94 master's
per-source-IP limiter is in `Master.cpp` and was replaced by b100's
per-`(ip,port)` limiter. Verify after the cron runs:

Verify what is actually running:

```bash
docker exec angels95-test-server /usr/local/bin/AngelServ --version
curl -s http://127.0.0.1:8080/status | python3 -m json.tool   # gamever, proto, max_players
docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' angels95-test-server
```

## Run

```bash
docker compose -f docker-compose.angels95.yml build
docker compose -f docker-compose.angels95.yml up -d
```

`angels95-test-server/GameData/` is **gitignored** (large) and `COPY`ed into the
image at build time. A fresh clone cannot build until you populate it from the
game repo or the `System-<tag>.zip`; the updater refuses to advance without it
rather than baking stale content.

All dedicated servers use `network_mode: host` so master heartbeats originate from the public interface. The master trusts a self-reported `--public-ip` only from a private source (LAN / local proxy); a public source is listed at its observed address. Point the master target at the VPS public IP (`--master` / `--master-http` / `--public-ip`).

## Auto-update

`scripts/angels95-update.sh` polls the canonical `TribeWarez/Angels-95` releases
and rebuilds/recreates the master + dedicated servers when a new release is
published. It verifies both Linux assets exist, refuses to run without
`GameData`, never advances its state file on a failed build/recreate, and
checks the running image label after recreating. Run it from cron:

```bash
*/5 * * * * /path/to/angels95-master-server/scripts/angels95-update.sh
```

## Known limits (upstream)

- **b94 master:** rate-limits heartbeats to 1 per 1.5s per **source IP**, so
  several servers behind one public IP cannot all appear in `/api/servers` at
  once. The membership is decided by heartbeat phase drift and can change after
  a restart. **Fixed in b100** (per-`ip:port` limiter + coarse per-source cap);
  b100 is pinned by default.
- **b94 `AngelServ`:** self-reports `0.2.1` / `build b58` and has no
  `--campaign`. b100 stamps the release tag into `gamever` and exposes it via
  `--version`; the wire id is reported separately as `proto`.
- **TDM:** b94 has no team-aware friendly-fire gate (`friendlyFire=1` is
  all-vs-all, and a team kill is awarded to the killer's team). **Fixed in
  b100** (enemy-only friendly fire, no team-kill score).
- The advertised `max_players` on b94 is 32 even though the shipped worlds
  author 8; b100 reports the world's cap and rejects the 9th joiner cleanly.
