# things-orca-server

[Orca](https://orca.dev)'s headless server (`orca serve`) on the Umbrel.
Repositories, worktrees, terminals and coding agents (Claude Code, Codex, …)
run here and keep running when the laptop sleeps. The Orca desktop app
connects to it under **Settings → Remote Orca Servers**; Orca Mobile can
connect too.

| Service | Image | What |
|---------|-------|------|
| `server` | `ghcr.io/kic2807/orca-server` | `orca serve` on port 6768 |

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
6. Clone repositories (e.g. into `~/projects`) and open them in Orca on the
   server.

## Storage

| Host | Container | What |
|------|-----------|------|
| `app-data/things-orca-server/data/home` | `/home/orca` | everything: Orca's profile (`~/.config/orca`: pairing identity, sessions, stored credentials), agent logins (`~/.claude`, `~/.codex`), `~/.local` tools, git/gh/ssh config, cloned repos |
| `/etc/machine-id` (read-only) | `/etc/machine-id` | Orca seals stored credentials with a key mixed with the machine ID; the host's stays the same across image updates |

Uninstalling deletes all of it, including uncommitted work in worktrees.
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
