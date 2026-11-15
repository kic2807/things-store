# things-steam-headless

[Steam Headless](https://steamheadless.com) V2: a KDE Plasma (Wayland) desktop
with Steam, Proton and Sunshine in one container, with no monitor attached.
Play from:

- a **browser**: the Steam Headless UI (SHUI) streams the desktop over WebRTC
  on `https://<umbrel-ip>:8483`, and also shows logs, services and the
  Sunshine settings
- **Moonlight** (phones, Apple TV, Android TV, Steam Deck, PCs) through the
  built-in Sunshine
- **Steam Remote Play / Steam Link**

| Service | Image | What |
|---------|-------|------|
| `setup` | `josh5/steam-headless` (same image) | one-shot on every start: owns `Downloads/steam`, raises two host kernel limits, writes the Sunshine drop-in, exits |
| `orbit-agent` | `ghcr.io/kic2807/orbit-agent` (private) | one-shot on every start: installs the [Orbit agent](#orbit-agent) into app data, exits |
| `open` | `ghcr.io/kic2807/caddy-cloudflare` (as things-caddy) | home screen icon: page on `127.0.0.1:30112` that forwards to `https://<host>:8483` |
| `desktop` | `josh5/steam-headless` | the desktop, host network |

## Requirements

- **GPU** with hardware video encoding (Intel or AMD) as
  `/dev/dri/renderD128`; upstream refuses software encoding. An Intel N100
  runs 2D, indie and older games; modern 3D needs more (e.g. Arc B390). New
  Intel generations need kernel support too: Arc B390 (Panther Lake) needs
  Linux 6.17+ (umbrelOS 2.1: 7.2; umbrelOS 2.0: 6.12, too old).
- **RAM:** 16 GB host minimum (upstream). The idle desktop uses about 1.5 GB.
- **Docker 28+** for `writable-cgroups` (umbrelOS 2.0: 28.5, 2.1: 29).
- Host devices `/dev/uinput`, `/dev/uhid`, `/dev/fuse` (present on umbrelOS):

  ```sh
  ls -l /dev/uinput /dev/uhid /dev/fuse /dev/dri/
  ```

  With a second GPU (`renderD129`), find the right node with
  `ls -l /dev/dri/by-path/`.

## Setup

1. Install the app. The first start takes a few minutes (large image,
   systemd boot).
2. Get the **temporary password** from the log:

   ```sh
   sudo docker logs things-steam-headless_desktop_1 2>&1 | grep -A1 'Temporary password'
   ```

3. Open the app from the home screen (it forwards to
   `https://<host>:8483`), or directly **`https://<umbrel-ip>:8483`**, and
   accept the self-signed certificate.
4. Sign in as **`steamheadless`** (fixed in the image, cannot be renamed) with
   the temporary password and choose a permanent one. Sunshine starts after
   this step.
5. In the streamed desktop, log in to Steam. The container has already set
   up a library in `/mnt/games/GameLibrary/Steam`
   (= `Downloads/steam/GameLibrary/Steam`); install games there.
6. **Moonlight:** add the Umbrel **by IP** (it is not discovered, see
   [umbrelOS specifics](#umbrelos-specifics)) and enter the PIN Moonlight
   shows on SHUI's **Sunshine** page. From outside the LAN, use the Umbrel's
   Tailscale IP, or Steam Link / Remote Play for Steam games.

## Storage

| Host | Container | What |
|------|-----------|------|
| `Downloads/steam` | `/mnt/games` | games (`GameLibrary/Steam`, created by the container) |
| `app-data/…/data/home` | `/home/steamheadless` | desktop profile, Steam client, Proton prefixes, saves |
| `app-data/…/data/state` | `/var/lib/steam-headless` | SHUI credentials and TLS certificate |
| `app-data/…/data/journal` | `/var/log/journal` | systemd journal (7 days) |
| `app-data/…/data/orbit` | `/usr/local/bin/orbit-agent`, `/etc/systemd/system/orbit-agent.service`, `/etc/orbit-agent-token` (read-only) | Orbit agent binary, unit and access token (token made once, kept) |
| `app-data/…/data/sunshine.service.d` | `/etc/systemd/system/steam-headless-sunshine.service.d` (read-only) | Sunshine drop-in, rewritten by `setup` on every start |

Uninstalling deletes the app data (Steam login, saves not in Steam Cloud,
Proton prefixes) but keeps the games in `Downloads/steam`.

## Network and security

- **Host network**, as upstream recommends for one container: SHUI on
  TCP+UDP 8483, Sunshine on 47984–48010, Orbit agent on TCP 47800, Steam
  Remote Play on its usual ports.
- **LAN and Tailscale only.** Do not port-forward any of these. SHUI has a
  login, Sunshine's settings sit behind it, Moonlight needs PIN pairing.
  Browser streaming works over Tailscale too (WebRTC uses UDP 8483).
- **Privileges:** the most privileged app in the store. The desktop gets
  `SYS_ADMIN`, `NET_ADMIN`, `SYS_PTRACE`, `SYS_NICE`, `DAC_READ_SEARCH` and
  `SYS_RESOURCE`, no seccomp or AppArmor, unmasked `/proc` and `/sys`
  (`systempaths=unconfined`), writable cgroups, all input devices (`c 13:*`)
  and the host network: upstream's requirements for systemd, sandboxes and
  virtual input, plus `SYS_RESOURCE` (below). Sunshine, which runs as `steamheadless`, gets
  `SYS_NICE` only. A compromised game or desktop
  reaches the host more easily than with other apps. The `setup` helper runs
  privileged for the few seconds it takes (reduced capabilities could not
  raise the inotify limit, 2.44-4).
- **Caddy:** upstream supports a reverse proxy for SHUI (HTTPS/WebSocket,
  WebRTC UDP still direct to 8483). Not set up here.

## umbrelOS specifics

Differences from upstream's compose, found on the first installs
(2026-11, umbrelOS 2.0, N100):

| Symptom | Cause | Fix |
|---------|-------|-----|
| Desktop restarts in a loop: `runuser: cannot open session: Permission denied` | Host `render` group (GID 991, owner of `renderD128`) is `pipewire` in the image. The desktop user joins it for GPU access, and the image's `limits.d/25-pw-rlimits.conf` (rtprio 70, nice -19) then needs `SYS_RESOURCE`. Raised ulimits alone did not help. | `SYS_RESOURCE` + `ulimits` on `desktop` (2.44-2) |
| `https://<ip>:8483` shows *Client sent an HTTP request to an HTTPS server* | umbrelOS puts its own proxy (Umbrel login, "Umbrel Local HTTPS CA") on an app's **manifest port** and forwards plain HTTP to `127.0.0.1:<port>`; SHUI is HTTPS only. | Manifest port 30112 (2.44-3); `open` answers there and forwards the browser to `https://<host>:8483` (2.44-7) |
| Moonlight does not discover the Umbrel | umbrelOS holds mDNS (UDP 5353), so the container disables its Avahi. | Add the Umbrel by IP |
| Sunshine: *CAP_SYS_NICE capability is missing* (stream may stutter when a game holds the GPU at 100%) | Sunshine's unit runs it as `steamheadless` (`User=`), so it gets none of the container's capabilities, although `SYS_NICE` is in `cap_add` (upstream has the same). | `setup` writes a drop-in with `AmbientCapabilities=CAP_SYS_NICE`, mounted read-only into `steam-headless-sunshine.service.d` (2.44-5) |

`setup` also raises two host kernel limits that umbrelOS sets too low, on
every start (they reset on reboot; only raised, never lowered):

| Setting | Minimum | Why |
|---------|---------|-----|
| `fs.inotify.max_user_instances` | 1024 | KDE and Steam watch many files; `EMFILE: Too many open files` otherwise (umbrelOS 2.0: 256) |
| `vm.max_map_count` | 1048576 | Proton games crash with `Cannot allocate memory` otherwise |

Its output: `sudo docker logs things-steam-headless_setup_1`. A `WARNING`
line means a limit could not be raised; the desktop starts anyway.

## Orbit agent

The agent for the [Orbit launcher](https://github.com/kic2807/orbit-launcher)
(private repository; deploy notes in `agent/deploy/README.md`, API in
`agent/API.md`). It runs inside the desktop as a systemd service under
`steamheadless` and starts with Sunshine (after the first SHUI sign-in): it
lists the Steam library, launches and quits games through the running Steam
client, reports game start/ready/exit events and serves artwork (IGDB). HTTP
on **TCP 47800**, every route except `/v1/health` needs the access token.
LAN and Tailscale only: do not port-forward 47800.

**Before updating to 2.44-7:** the installer image is private, so the
Umbrel pulls it with its ghcr.io login (the one made for things-subsy-cost).
Check it works, or the whole app fails to update:

```sh
sudo docker pull ghcr.io/kic2807/orbit-agent:0.1.0
```

If that is denied: `sudo docker login ghcr.io -u kic2807` with a token that
has `read:packages`.

**Connect Orbit:** read the token once and enter it in Orbit (Settings →
Network → Agent token; port 47800):

```sh
sudo cat ~/umbrel/app-data/things-steam-headless/data/orbit/token
```

Optional: in Sunshine (SHUI → Sunshine), add an application named `Orbit`
with no command; Orbit streams it while the agent runs the game, otherwise
`Desktop`.

**Updates:** a new agent version is a new `agent/VERSION` in orbit-launcher
(its workflow pushes `orbit-agent:<VERSION>`), then a new pin here. Not
automated: the store's update job cannot read the private package.

## Troubleshooting

```sh
C=things-steam-headless_desktop_1
sudo docker logs --tail 100 $C
sudo docker exec $C /usr/local/bin/steam-headless-healthcheck
sudo docker exec $C systemctl --failed
sudo docker exec $C journalctl -u steam-headless-shui --no-pager -n 50
sudo docker exec $C cat /run/steam-headless/configuration-warnings.json
```

Orbit agent:

```sh
sudo docker logs things-steam-headless_orbit-agent_1      # "orbit-agent: installed"
sudo docker exec $C systemctl status orbit-agent --no-pager
sudo docker exec $C curl -s localhost:47800/v1/health      # {"status":"ok"}
sudo docker exec $C sh -c 'curl -s -H "Authorization: Bearer $(cat /etc/orbit-agent-token)" localhost:47800/v1/library'
```

The healthcheck ends with `health=healthy` when all is well. Upstream's
guide: <https://steamheadless.com/docs/>.

- *Stream stays on "Connecting…"*: UDP 8483 is blocked between client and
  Umbrel.
- *"No supported hardware encoder passed probe"*: the GPU or its driver is
  not usable in the container (check `/dev/dri` and the kernel version).
- *Sunshine not running (port 47990 refused)*: it stays off until the first
  SHUI sign-in is completed.
- *`steam-headless-steam.service: Failed with result 'exit-code'` on a fresh
  install*: the first launch downloads and installs a ~480 MB Steam client
  update (`~/.local/share/Steam/logs/bootstrap_log.txt`); systemd restarts
  Steam and the next start runs. The healthcheck shows `restarts=1`.

## Updates

Tags are `<major>.<minor>.<YYYYMMDD>.<n>` (e.g. `2.44.20261019.1`); V2 has
no GitHub releases. Every new image opens a PR that is never merged on its
own: a desktop, Steam or driver change can break streaming, so update when
there is time to test.

## Test checklist

N100 box, umbrelOS 2.0:

- [x] `setup` exits 0, `Downloads/steam` owned by 1000, limits raised
- [x] desktop boots, healthcheck healthy (31 checks)
- [x] SHUI sign-in, permanent password set (2.44-3)
- [x] `setup` after a host reboot (2.44-6, privileged again): `256 -> 1024`,
  no `WARNING` (2.44-4's reduced capabilities failed on inotify after a reboot)
- [x] Sunshine drop-in applied: `CapAmb: 0000000000800000` (`CapEff` 0: Sunshine
  keeps it off until needed)
- [x] Sunshine log: `EGL: context priority set to HIGH`, no *CAP_SYS_NICE
  capability is missing* (2.44-5)
- [ ] Home screen icon forwards to `https://<host>:8483` (2.44-7)
- [ ] Orbit agent: `orbit-agent: installed`, `systemctl status orbit-agent`
  active, `/v1/health` ok, `/v1/library` lists games, `/v1/launch` starts
  one, `/v1/session` turns `ready`, `/v1/quit` closes it (2.44-7)
- [ ] Browser stream with hardware encoding (no encoder probe warning)
- [ ] Steam login, a game installs into `Downloads/steam/GameLibrary/Steam`
- [ ] Moonlight pairing and a game stream with controller input
- [ ] Moonlight / browser stream over Tailscale
