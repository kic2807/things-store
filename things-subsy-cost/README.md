# things-subsy-cost

[subsy-cost](https://github.com/kic2807/subsy-cost) backend: pulls Subsy cost
data from Superset into SQLite on a schedule (09/12/15/18/21 KST) and serves
precomputed figures to the Subsy Cost iOS app. No web UI; reached only through
Cloudflare Tunnel + Cloudflare Access.

Images:

- `ghcr.io/kic2807/subsy-cost-server` (linux/amd64), built by GitHub Actions
  in the subsy-cost repo. **Not** updated by this store's automation; release
  it by hand (see below).
- `cloudflare/cloudflared`, updated by the image automation.

## Layout

`~/umbrel/app-data/things-subsy-cost/data/` is mounted at `/data`:

| Path | What |
|------|------|
| `.env` | settings and secrets (from `.env.example`) |
| `subsy-cost.db` | SQLite (raw rows, snapshots, sync runs), created by the app |
| `backups/` | daily 04:00 KST copies, 7 kept |
| `config/` | optional `workspaces.json` / `annotations.json` overriding the built-in ones |

The server runs as 1000:1000.

## Setup

1. Cloudflare (full steps in the subsy-cost README, section 2): create a
   tunnel, add a public hostname pointing to
   **`http://things-subsy-cost_server_1:8080`**, create an Access service
   token and a self-hosted Access application whose only policy is
   *Service Auth* with that token.
2. Install this app, then on the Umbrel terminal:

   ```sh
   cd ~/umbrel/app-data/things-subsy-cost/data
   nano .env        # keys from .env.example
   chmod 600 .env
   ```

3. Restart the app. The first start runs a full sync (about 10 seconds):

   ```sh
   sudo docker logs -f things-subsy-cost_server_1   # listening … full sync chunk … sync ok
   ```

4. Pair the iPhone: print the setup QR and scan it from the app's first screen,
   then clear the terminal (the QR contains the tokens).

   ```sh
   sudo docker exec things-subsy-cost_server_1 /subsy-cost setup-qr
   ```

## Commands

```sh
sudo docker exec things-subsy-cost_server_1 /subsy-cost verify        # acceptance figures
sudo docker exec things-subsy-cost_server_1 /subsy-cost sync --full   # full resync now
sudo docker logs things-subsy-cost_cloudflared_1                      # tunnel status
```

## Releasing a new server version

1. In subsy-cost: tag `vX.Y.Z` and push. The *Build server image* workflow
   prints `image: ghcr.io/kic2807/subsy-cost-server:X.Y.Z@sha256:…` in its
   run summary.
2. Here: put that line in `docker-compose.yml`, set `version` and
   `releaseNotes` in `umbrel-app.yml`, push to `main`.
