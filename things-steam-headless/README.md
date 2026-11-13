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
| `setup` | `josh5/steam-headless` (same image) | one-shot on every start: owns `Downloads/steam`, raises two host kernel limits, exits |
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

3. Open **`https://<umbrel-ip>:8483`** (e.g. `https://192.168.1.100:8483`)
   and accept the self-signed certificate. **Not the home screen icon**: its
   port is a placeholder (see [umbrelOS specifics](#umbrelos-specifics)).
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

Uninstalling deletes the app data (Steam login, saves not in Steam Cloud,
Proton prefixes) but keeps the games in `Downloads/steam`.

## Network and security

- **Host network**, as upstream recommends for one container: SHUI on
  TCP+UDP 8483, Sunshine on 47984–48010, Steam Remote Play on its usual
  ports.
- **LAN and Tailscale only.** Do not port-forward any of these. SHUI has a
  login, Sunshine's settings sit behind it, Moonlight needs PIN pairing.
  Browser streaming works over Tailscale too (WebRTC uses UDP 8483).
- **Privileges:** the most privileged app in the store. The desktop gets
  `SYS_ADMIN`, `NET_ADMIN`, `SYS_PTRACE`, `SYS_NICE`, `DAC_READ_SEARCH` and
  `SYS_RESOURCE`, no seccomp or AppArmor, unmasked `/proc` and `/sys`
  (`systempaths=unconfined`), writable cgroups, all input devices (`c 13:*`)
  and the host network: upstream's requirements for systemd, sandboxes and
  virtual input, plus `SYS_RESOURCE` (below). A compromised game or desktop
  reaches the host more easily than with other apps. The `setup` helper only
  gets `CHOWN` and `SYS_RESOURCE` for a few seconds.
- **Caddy:** upstream supports a reverse proxy for SHUI (HTTPS/WebSocket,
  WebRTC UDP still direct to 8483). Not set up here.

## umbrelOS specifics

Three differences from upstream's compose, found on the first install
(2026-11-12, umbrelOS 2.0, N100):

| Symptom | Cause | Fix |
|---------|-------|-----|
| Desktop restarts in a loop: `runuser: cannot open session: Permission denied` | Host `render` group (GID 991, owner of `renderD128`) is `pipewire` in the image. The desktop user joins it for GPU access, and the image's `limits.d/25-pw-rlimits.conf` (rtprio 70, nice -19) then needs `SYS_RESOURCE`. Raised ulimits alone did not help. | `SYS_RESOURCE` + `ulimits` on `desktop` (2.44-2) |
| `https://<ip>:8483` shows *Client sent an HTTP request to an HTTPS server* | umbrelOS puts its own HTTPS proxy ("Umbrel Local HTTPS CA") on an app's **manifest port** and forwards plain HTTP; SHUI is HTTPS only. | Manifest port is a placeholder (30112); open 8483 directly (2.44-3) |
| Moonlight does not discover the Umbrel | umbrelOS holds mDNS (UDP 5353), so the container disables its Avahi. | Add the Umbrel by IP |

`setup` also raises two host kernel limits that umbrelOS sets too low, on
every start (they reset on reboot; only raised, never lowered):

| Setting | Minimum | Why |
|---------|---------|-----|
| `fs.inotify.max_user_instances` | 1024 | KDE and Steam watch many files; `EMFILE: Too many open files` otherwise (umbrelOS 2.0: 256) |
| `vm.max_map_count` | 1048576 | Proton games crash with `Cannot allocate memory` otherwise |

Its output: `sudo docker logs things-steam-headless_setup_1`. A `WARNING`
line means a limit could not be raised; the desktop starts anyway.

## Troubleshooting

```sh
C=things-steam-headless_desktop_1
sudo docker logs --tail 100 $C
sudo docker exec $C /usr/local/bin/steam-headless-healthcheck
sudo docker exec $C systemctl --failed
sudo docker exec $C journalctl -u steam-headless-shui --no-pager -n 50
sudo docker exec $C cat /run/steam-headless/configuration-warnings.json
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
- [x] `setup` with reduced capabilities (2.44-4): no `WARNING` lines
- [ ] Browser stream with hardware encoding (no encoder probe warning)
- [ ] Steam login, a game installs into `Downloads/steam/GameLibrary/Steam`
- [ ] Moonlight pairing and a game stream with controller input
- [ ] Moonlight / browser stream over Tailscale
