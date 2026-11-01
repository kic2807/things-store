# things-stump

[Stump](https://github.com/stumpapp/stump): comics, manga and ebook server with
OPDS, Kobo and KOReader sync, and a mobile app.

## Nightly builds

This app runs Stump's **nightly** image (`aaronleopold/stump:nightly`, pinned
by digest). The store's update job follows that tag: when a new nightly is
published it re-pins the digest and sets the version to
`nightly-<UTC time found>`, so Umbrel shows an update. Nightlies can break or
migrate the database in ways an older build cannot read; back up
`data/config/` before updating if your library matters, and there is no way
back to the 0.1.x release with the same data.

## Layout

| Host (`~/umbrel/app-data/things-stump/data/` unless noted) | Container | What |
|---|---|---|
| `config/` | `/config` | database, thumbnails, logs |
| Umbrel `Downloads/comics` (default) | `/data` | your library files |
| `.env` (optional) | env | extra `STUMP_*` settings |

Change the library folder in Umbrel: right-click Stump → Settings → Folder
access → **Comics**. Any folder (Home, external drive, network share) works.

## Setup

1. Install, put books into `Downloads/comics` (or pick another folder as above).
2. Open Stump from the home screen and create the owner account.
3. Libraries → Create → path `/data` (or a subfolder like `/data/comics`).

Port **10801** (Stump's default, so reader apps can use their usual setting):

- Web UI: `http://<umbrel>:10801` (behind Umbrel login)
- OPDS: `http://<umbrel>:10801/opds/v1.2/catalog`
- Reader endpoints `/opds`, `/api`, `/kobo`, `/koreader` skip Umbrel login and
  use Stump accounts.

Set in `docker-compose.yml`:

- `STUMP_ENABLE_UPLOAD=true`: uploads are off by default, and setting a
  series or book cover from an image file is an upload (Stump rejects it
  otherwise). Only the owner, or users given the upload permission, can
  upload; files up to 20 MB.
- `STUMP_TRUST_PROXY_HEADERS=true`: Stump is always reached through Caddy or
  Umbrel's app_proxy, which set `X-Forwarded-Proto`; with it Stump builds
  `https://` links for `comics.` (OPDS, Kobo, EPUB) and stops logging
  `Proxy scheme headers present but trust_proxy_headers is false` on every
  request.

## Public address

Stump is served at `https://comics.<domain>` (Caddy host `comics.` →
`things-stump_server_1:10801`, already in the Caddyfile example; add
`comics.<domain>` to cloudflare-ddns `DOMAINS`).
