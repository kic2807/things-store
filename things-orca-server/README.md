# things-orca-server

[Orca](https://orca.dev)'s headless server (`orca serve`) on the Umbrel.
Repositories, worktrees, terminals and coding agents (Claude Code, Codex, …)
run here and keep running when the laptop sleeps. The Orca desktop app
connects to it under **Settings → Remote Orca Servers**; Orca Mobile can
connect too.

| Service | Image | What |
|---------|-------|------|
| `server` | `ghcr.io/kic2807/orca-server` | `orca serve` on port 6768 |
| `tailcat` | `ghcr.io/kic2807/orca-server` | optional tunnel to port 6768 without Tailscale on the client ([tailcat](https://github.com/tailscale/tailcat)); off by default |
| `tailscale` | `tailscale/tailscale` | optional proxy through a Tailscale exit node, for git hosts that only accept one network; off by default |

The image is built in this repository
([`.github/orca-server`](../.github/orca-server/Dockerfile)): Orca's official
`orca-server-linux-x64.tar.gz` release bundle (its own Node, no desktop app),
checked against the SHA-256 GitHub lists for it, on Debian trixie with `git`,
`gh`, `git-lfs`, `node`/`npm`, `python3`, `ripgrep` and build tools.

## Setup

Commands run on the Umbrel (SSH or Settings → Advanced settings → Terminal):

```sh
C=things-orca-server_server_1
```

1. Install the app. There is no web UI; the home screen icon does nothing
   (its port, 30113, is a placeholder).
2. **Pair the Mac.** Create an access link, with the address the Mac should
   dial (the Umbrel's LAN IP, or its Tailscale IP to also work away from
   home):

   ```sh
   sudo docker exec $C orca pair --address <umbrel-ip>
   ```

   In the Orca desktop app: **Settings → Remote Orca Servers → Add Server**,
   paste the link. Treat the link like a password. It is reused until it is
   used (`--rotate` makes a new one); each client gets its own token, which
   can be revoked under **Shared Server Access**.

   Orca Mobile: `orca pair --mobile --address <umbrel-ip>` prints a QR code.

3. **Install the agent CLIs** into the persistent home (they update
   themselves there):

   ```sh
   sudo docker exec -it $C bash -l
   curl -fsSL https://claude.ai/install.sh | bash    # Claude Code -> ~/.local/bin
   npm install -g @openai/codex                      # Codex -> ~/.local (NPM_CONFIG_PREFIX)
   ```

4. **Sign in**, still in that shell, or from a terminal in Orca on the
   server: `claude` (follow the login link), `codex login --device-auth`.
   Orca can also add accounts: `orca account add --agent claude`.
5. **Git:** `gh auth login` (then `gh auth setup-git`), or an SSH key in
   `~/.ssh`. Set `git config --global user.name/user.email`; for
   kic2807 repos use the GitHub noreply address.
6. Clone repositories into `~/projects`, or copy project folders into
   **Documents/projects** with the Umbrel Files app (or over SMB): that
   folder is `~/projects` on the server (pick another folder in the app's
   settings under Storage). Open them in Orca on the
   server.

## Git hosts behind an exit node

Some git hosts only accept connections from one network, for example a work
GitLab that allows only the office IP. If a Tailscale exit node sits in that
network, the `tailscale` service gives git a proxy that leaves through it.
Only the hosts you configure use it; the Umbrel and the server's other
traffic (agents' APIs, GitHub, npm) stay direct.

1. **Tailscale admin console:** Settings → Keys → **Generate auth key**. The
   exit node must be approved, and your tailnet policy must let new devices
   use it (the default policy does).
2. **`.env`** on the Umbrel (keys from [`.env.example`](.env.example)):

   ```sh
   D=~/umbrel/app-data/things-orca-server/data
   nano $D/.env     # TS_AUTHKEY=tskey-auth-...  EXIT_NODE=<device name>
   chmod 600 $D/.env
   ```

   Restart the app (right-click the icon → Restart). In the admin console,
   turn off key expiry for the new device `things-orca-server`. Check:

   ```sh
   sudo docker logs things-orca-server_tailscale_1 2>&1 | grep -E 'proxy off|exit node set'
   sudo docker exec $C curl -s -x http://things-orca-server_tailscale_1:1055 https://ifconfig.me; echo
   ```

   Expected: `exit node set: <device>` and the exit node network's public IP.

3. **Git**, in the server (`sudo docker exec -it $C bash -l`), once per
   host:

   ```sh
   git config --global http.https://<git-host>/.proxy http://things-orca-server_tailscale_1:1055
   ```

   For git over SSH instead, in `~/.ssh/config`:

   ```
   Host <git-host>
     ProxyCommand nc -X 5 -x things-orca-server_tailscale_1:1080 %h %p
   ```

   (needs `nc` from netcat-openbsd, not in the image; HTTPS is simpler).

The exit node's own connection decides the speed; a node reached through a
Tailscale relay (DERP) is slow for large clones.

## Access without Tailscale (tailcat)

[tailcat](https://github.com/tailscale/tailcat) is Tailscale's open-source
netcat-style tool: WireGuard tunnels with NAT traversal, bootstrapped
through Tailscale's free tailcat relays, with no Tailscale account or
tailnet. The `tailcat` service serves only Orca's port 6768 to the client
keys you allow; the Mac runs `tailcat forward`, and Orca connects to
`127.0.0.1`. It works from any network and leaves the Mac's Tailscale app
(if any) free for other tailnets.

1. **Mac**: install tailcat and create its client key, which prints a
   `nodekey:…` line:

   ```sh
   brew install tailcat
   tailcat genkey --client --key=client-default
   ```

2. **Umbrel**: the app's settings → **Environment variables** → service
   **tailcat** → `TAILCAT_ALLOW` = that `nodekey:…` (several keys:
   comma-separated). The app restarts. Read the server's address:

   ```sh
   cat ~/umbrel/app-data/things-orca-server/data/tailcat/address; echo
   ```

3. **Mac**: keep the forward running as a login item (LaunchAgent), with
   the address from step 2:

   ```sh
   A=tc...   # the address
   L=~/Library/LaunchAgents/things.orca-tailcat.plist
   cat > $L <<PLIST
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0"><dict>
     <key>Label</key><string>things.orca-tailcat</string>
     <key>ProgramArguments</key><array>
       <string>$(brew --prefix)/bin/tailcat</string><string>forward</string>
       <string>$A</string><string>16768:6768</string>
     </array>
     <key>RunAtLoad</key><true/>
     <key>KeepAlive</key><true/>
     <key>StandardErrorPath</key><string>/tmp/orca-tailcat.log</string>
   </dict></plist>
   PLIST
   launchctl bootstrap gui/$(id -u) $L
   tailcat ping --until-direct $A   # "via <ip>:<port>" = direct, "via DERP(...)" = relayed
   ```

4. **Pair** with the local end of the tunnel, and add the link in Orca
   (Settings → Remote Orca Servers → Add Server):

   ```sh
   sudo docker exec $C orca pair --rotate --address 127.0.0.1:16768
   ```

Notes:

- The address and the key file (`data/tailcat/.config/tailcat/keys`)
  identify the server; only allowed client keys get through, and Orca's
  pairing token is still needed. To change the address, delete
  `data/tailcat/.config` and restart the app (then update the LaunchAgent).
- Most connections go direct after the start. On networks that block that,
  traffic stays on Tailscale's shared relays: rate-limited (no published
  figure), logged as metadata, fine for terminals and agents, slow for bulk
  transfers. tailcat can use your own relay (`derper`) instead.
- To stop on the Mac: `launchctl bootout gui/$(id -u)/things.orca-tailcat`.
  On the Umbrel: remove `TAILCAT_ALLOW`.
- The service shares the server container's network (tailcat forwards
  ports to its own localhost only). `TAILCAT_ALLOW` must contain at least one
  `nodekey:…`: tailcat with an empty allow list would accept every client,
  so the service stays off instead.
- tailcat's version is pinned in the image (`.github/orca-server/Dockerfile`)
  and updated by hand.

## Storage

| Host | Container | What |
|------|-----------|------|
| `app-data/things-orca-server/data/home` | `/home/orca` | everything: Orca's profile (`~/.config/orca`: pairing identity, sessions, stored credentials), agent logins (`~/.claude`, `~/.codex`), `~/.local` tools, git/gh/ssh config, cloned repos |
| `home/Documents/projects` | `/home/orca/projects` | shared projects: Documents/projects in the Files app; kept on uninstall |
| `app-data/things-orca-server/data/tailscale` | `/var/lib/tailscale` (`tailscale`) | the proxy's Tailscale node state |
| `app-data/things-orca-server/data/.env` | (`tailscale`) | `TS_AUTHKEY`, `EXIT_NODE`; optional |
| `app-data/things-orca-server/data/tailcat` | `/tailcat` (`tailcat`) | tailcat server key (the address stays the same) and `address` |
| `/etc/machine-id` (read-only) | `/etc/machine-id` | Orca seals stored credentials with a key mixed with the machine ID; the host's stays the same across image updates |

Uninstalling deletes the app-data folder, including uncommitted work in
worktrees outside `~/projects`; Documents/projects stays.
Orca's credential key sits next to the credentials in the same folder, so
anyone who can read `app-data` (or a backup of it) can read them.

## Network and security

- **Port 6768**, WebSocket, published directly. The runtime accepts
  clients from LAN and Tailscale addresses only and every client needs a
  pairing token. **Do not port-forward 6768**; from outside, use Tailscale.
- The container runs as UID 1000 (the umbrel user) with **no capabilities**
  and `no-new-privileges`: agents cannot use `sudo` or `apt`. Install
  tools into `~/.local` (npm, pip `--user`, `uv`, `mise`, …). No Docker
  socket, so agents cannot run containers.
- Agents can reach anything on your LAN that the Umbrel can, and they run
  with your agent and GitHub logins: same trust as running them on the Mac.
- `orca pair` works only from inside the container (paired clients cannot
  create pairing offers).

## Troubleshooting

```sh
sudo docker logs --tail 50 $C                 # "Orca server ready", "Terminal daemon: live"
sudo docker exec $C orca status               # runtimeState: ready
```

- *"Browser automation has no backend on this host"* in `orca status`:
  expected, no Chromium in the image. Everything else works.
- *`linger off` / `daemon-scope-unavailable`* in the log: expected in a
  container; terminals still survive a server restart inside it, not a
  container restart.
- *Pairing link in the startup log*: it points at 127.0.0.1 and no client
  can use it; make one with `orca pair --address <umbrel-ip>`.
- *`orca pair` says pairing is disabled (`disabled_by_operator`)*: the
  server was started with `--no-pairing` (before 1.4.263-1); update the app.
- *Pairing link does not connect*: the address given to `--address` must be
  reachable from the client (LAN IP at home, Tailscale IP elsewhere), port
  6768.

## Updates

Tags are `<orca version>-r<n>` (e.g. `1.4.258-r1`). The image is built daily
from the newest Orca release and the update PR is merged automatically
(minor and patch; major versions get a PR to review). Keep the server close
to the desktop app's version; both update often.

## Test checklist

- [ ] App starts: `Orca server ready`, `Terminal daemon: live`
- [ ] `orca pair --address <umbrel-ip>` gives a link; Mac adds the server
- [ ] Claude Code and Codex installed and signed in, survive an app restart
- [ ] Clone a repo with `gh`, create a worktree and run an agent from the Mac
- [ ] Connect over Tailscale away from home
- [ ] Stored credentials still readable after an app update
- [ ] tailcat: `orca-tailcat: off` without `TAILCAT_ALLOW`; with it, the Mac's forward connects (`tailcat ping`), Orca pairs over `127.0.0.1:16768`, a key not in the list is refused
- [ ] Exit-node proxy: `exit node set`, a fetch from a host behind it works; without `.env` the log says `proxy off`
