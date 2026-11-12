# things-steam-headless

[Steam Headless](https://steamheadless.com) V2: a KDE Plasma (Wayland) desktop
with Steam, Proton and Sunshine in one container, with no monitor attached.
Play from:

- a **browser**: the Steam Headless UI (SHUI) streams the desktop over WebRTC
  on `https://<umbrel>:8483`, and also shows logs, services and the Sunshine
  settings
- **Moonlight** (phones, Apple TV, Android TV, Steam Deck, PCs) through the
  built-in Sunshine
- **Steam Remote Play / Steam Link**

| Service | Image | What |
|---------|-------|------|
| `setup` | `josh5/steam-headless` (same image) | one-shot: creates `Downloads/steam`, raises two host kernel limits, then exits |
| `desktop` | `josh5/steam-headless` | the desktop, host network |

## Requirements

- **GPU:** Intel or AMD with hardware video encoding, as `/dev/dri/renderD128`.
  Upstream refuses software encoding. An Intel N100 works for 2D, indie and
  older games; modern 3D needs a stronger GPU (e.g. Arc B390). A new Intel
  generation also needs a kernel that supports it: Panther Lake / Arc B390
  needs Linux 6.17+ (umbrelOS 2.1: 7.2; umbrelOS 2.0: 6.12, too old).
- **RAM:** upstream's minimum is 16 GB for the host; the idle desktop uses
  about 1.5 GB, games come on top.
- **Docker 28+** for `writable-cgroups` (umbrelOS 2.0 ships 28.5).
- Host devices `/dev/uinput`, `/dev/uhid`, `/dev/fuse` (present on umbrelOS).
  Check before installing:

  ```sh
  ls -l /dev/uinput /dev/uhid /dev/fuse /dev/dri/
  ```

  If `/dev/dri` has a second render node (`renderD129`, e.g. a second GPU),
  check which one is which with `ls -l /dev/dri/by-path/`.

## Setup

1. Install the app and wait until it is running. The first start takes a
   while (large image, systemd boot).
2. **Temporary password:** the first sign-in uses a bootstrap password that
   the container prints to its log:

   ```sh
   sudo docker logs things-steam-headless_desktop_1 2>&1 | grep -i -A2 password
   ```

3. Open **`https://<umbrel-ip>:8483`**, e.g. `https://192.168.1.100:8483`.
   It is HTTPS only with a self-signed certificate: accept the browser
   warning. The Umbrel home screen icon opens `http://…:8483`, which does not
   work.
4. Sign in with the temporary password and set the permanent admin password.
5. In the streamed desktop, log in to Steam. Then Steam → Settings →
   Storage → add **`/mnt/games`** as a library folder and make it the
   default, so games go to `Downloads/steam` instead of the app's data.
6. **Moonlight:** in SHUI open **Sunshine**, then add the Umbrel in Moonlight
   (by IP if it is not found) and enter the PIN Moonlight shows in SHUI's
   Sunshine page.

## Storage

| Host | Container | What |
|------|-----------|------|
| `Downloads/steam` | `/mnt/games` | game library (add it in Steam, step 5) |
| `app-data/…/data/home` | `/home/steamheadless` | desktop profile, Steam client, Proton prefixes, saves |
| `app-data/…/data/state` | `/var/lib/steam-headless` | SHUI credentials and TLS certificate |
| `app-data/…/data/journal` | `/var/log/journal` | systemd journal (7 days) |

Uninstalling the app deletes the app data (Steam login, saves that are not in
Steam Cloud, Proton prefixes) but not the games in `Downloads/steam`.

## Network and security

- **Host network**, as upstream recommends for a single container: SHUI on
  TCP+UDP 8483, Sunshine on 47984–48010, Steam Remote Play on its usual
  ports. Steam and Sunshine advertise the Umbrel's hostname.
- **LAN and Tailscale only.** Do not port-forward these ports. SHUI has a
  login, Sunshine sits behind it, Moonlight needs PIN pairing.
- Browser streaming over Tailscale works because WebRTC uses the same UDP
  8483 port. Moonlight over Tailscale: add the Umbrel's Tailscale IP by hand.
- **Privileges:** this is the most privileged app in the store. The desktop
  gets `SYS_ADMIN`, `NET_ADMIN`, `SYS_PTRACE`, `SYS_RESOURCE` (see
  Troubleshooting), no seccomp/AppArmor, writable
  cgroups and the host network (upstream's requirements for systemd,
  sandboxes and virtual input). The `setup` helper runs `privileged` for a
  few seconds to change two kernel settings. A compromised game or desktop
  can reach the host more easily than with other apps.
- **Optional Caddy host** (private, e.g. `play.`): upstream supports a
  reverse proxy for HTTPS/WebSocket while WebRTC UDP goes directly to 8483.
  Not set up here.

## Host kernel limits

`setup` raises, on every app start (they reset on reboot):

| Setting | Minimum | Why |
|---------|---------|-----|
| `fs.inotify.max_user_instances` | 1024 | KDE and Steam watch many files; `EMFILE: Too many open files` otherwise |
| `vm.max_map_count` | 1048576 | Proton games crash with `Cannot allocate memory` otherwise |

It only raises values, never lowers them. See its output with
`sudo docker logs things-steam-headless_setup_1`.

## Troubleshooting

```sh
sudo docker logs --tail 100 things-steam-headless_desktop_1
sudo docker exec things-steam-headless_desktop_1 systemctl is-system-running
sudo docker exec things-steam-headless_desktop_1 systemctl --failed
sudo docker exec things-steam-headless_desktop_1 /usr/local/bin/steam-headless-healthcheck
curl -k https://127.0.0.1:8483/api/v1/health
```

`running` or `degraded` (an optional unit failed) is healthy. Upstream's
troubleshooting guide: <https://steamheadless.com/docs/>.

- *Web page loads but the stream stays on "Connecting…"*: UDP 8483 is
  blocked between the client and the Umbrel.
- *Restart loop with `runuser: cannot open session: Permission denied`*: on
  umbrelOS the host `render` group (GID 991) is `pipewire` inside the image,
  so the desktop user joins `pipewire` for GPU access, and the image's
  `25-pw-rlimits.conf` (rtprio 70, nice -19) can then only be applied with
  `SYS_RESOURCE`. Raised ulimits alone did not help (2.44-1); 2.44-2 adds
  `SYS_RESOURCE`, which made every case pass in a test container.
- *"No supported hardware encoder passed probe"*: the GPU or its video driver
  is not usable in the container (check `/dev/dri` and the kernel version).

## Updates

Image tags are `<major>.<minor>.<YYYYMMDD>.<n>` (e.g. `2.44.20261019.1`);
there are no GitHub releases for V2. Every new image opens a PR and is never
merged on its own: a desktop/Steam/driver change can break streaming, so
update when you have time to test.

## Test checklist

First install 2026-11-12 on the N100 box (umbrelOS 2.0): setup OK; the
desktop looped on a PAM limits error, fixed in 2.44-2. Still to test:

- [x] `setup` exits 0, `Downloads/steam` owned by 1000, both limits raised
- [ ] `systemctl is-system-running`: running/degraded
- [ ] SHUI sign-in with the temporary password, permanent password set
- [ ] Browser stream with hardware encoding (no encoder probe warning)
- [ ] Steam login, `/mnt/games` library, a game installs into `Downloads/steam`
- [ ] Moonlight pairing and a game stream with controller input
- [ ] Browser stream over Tailscale
