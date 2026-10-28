# things-cleanuparr

[Cleanuparr](https://github.com/Cleanuparr/Cleanuparr) watches the Sonarr and
Radarr queues and cleans up downloads that will never finish, which Sonarr and
Radarr do not do themselves: Transmission does not report a stalled torrent as
failed, so it stays in the queue forever.

For each stuck download it removes the torrent, **blocklists** the release in
Sonarr/Radarr (so it is not picked again) and **starts a new search**: the same
thing as removing it by hand and searching again.

| Service | Image | What |
|---------|-------|------|
| `server` | `ghcr.io/cleanuparr/cleanuparr` | web UI and jobs on `things-cleanuparr_server_1:11011`, settings in `data/config` |

Port **30110** (behind Umbrel login). Cleanuparr also has its own account.

## Setup

1. Install, open Cleanuparr from the home screen, create the account.
2. **Sonarr and Radarr Allowed Hosts:** Cleanuparr calls them as
   `sonarr_server_1` and `radarr_server_1`. In each app: Settings → General →
   Allowed Hosts, add that name (otherwise the connection test fails with
   400 Invalid Hostname).
3. **Sonarr / Radarr settings:** add an instance each:

   | | URL | API key |
   |---|---|---|
   | Sonarr | `http://sonarr_server_1:8989` | Sonarr → Settings → General → API Key |
   | Radarr | `http://radarr_server_1:7878` | Radarr → Settings → General → API Key |

4. **Download Clients:** add Transmission: host
   `http://transmission_server_1:9091`, URL base path `transmission` (Cleanuparr
   then calls `/transmission/rpc`), no username or password (Umbrel's
   Transmission has none). Test.
5. **Queue Cleaner:** enable it. Each run that finds a download stuck gives
   it a strike; at *Max Strikes* it is removed, blocklisted and searched
   again. A start that tolerates slow public torrents, with the default
   5-minute schedule:
   - add a **Stalled Download Rule**: privacy type *Public Torrents Only*,
     completion 0–100 %, *Max Strikes* 12 (about an hour without progress),
     *Reset Strikes on Progress* on
   - **Downloading Metadata Max Strikes**: 6
   - **Failed Import** *Max Strikes*: 3
6. Optional: **Seeker** (search for missing items and upgrades on a
   schedule), **Malware Blocker** (removes torrents containing blocked file
   types such as `.exe`), **Notifications** (Discord, ntfy, …).

The **Events** page lists every strike and removal, so check it after a day to
see the rules are not too eager.

## Notes

- **Through the VPN, stalls are more common:** Mullvad has no port
  forwarding, so Transmission can only connect to peers that accept incoming
  connections. Torrents with few seeders stall more often, which is what
  Cleanuparr handles.
- **No Downloads access:** Cleanuparr only talks to the APIs. The *Download
  Cleaner*'s unlinked-download feature (hardlink check) needs the downloads
  folder mounted; it is not set up here.

## Updates

Upstream treats a **minor** release (2.**10**.x → 2.**11**.0) as breaking: it
may change the database so that an older version cannot read it. The store's
update job therefore opens a PR for minor (and major) releases and never
merges it on its own; back up `data/config/` before merging. Patch releases
are merged automatically.

## Test results

Not tested on the Umbrel yet.
