# things-kavita

[Kavita](https://www.kavitareader.com): reading server for manga, webtoons,
comics and ebooks, with a web reader, OPDS, reading lists and an API used by
apps like Mihon/Tachiyomi.

It can run next to [things-komga](../things-komga/README.md) on the same
library folder, e.g. to compare them before switching. Komga-only add-ons
(things-komga-ko-meta) do not work with Kavita.

## Layout

| Host (`~/umbrel/app-data/things-kavita/data/` unless noted) | Container | What |
|---|---|---|
| `config/` | `/kavita/config` | database, covers, cache, logs, `appsettings.json` |
| Umbrel `Downloads/comics` (default, read-only) | `/books` | your library files |

The library defaults to Umbrel's `Downloads/comics`. Change it in Umbrel:
right-click Kavita → Settings → Folder access → **Comics** (it stays
read-only).

The official image only runs as root (upstream dropped `PUID`/`PGID`), so the
files in `config/` belong to root and the library is mounted read-only. Kavita
never writes to the library anyway.

## Setup

1. Install, put books into `Downloads/comics` (or pick another folder as above).
2. Open Kavita from the Umbrel home screen (port **5000**) and create the
   admin account.
3. Server settings → Libraries → **Add Library**: type Manga, Comic or Book,
   folder `/books` (or a subfolder like `/books/manga`).

Kavita expects one folder per series (`/books/manga/<Series>/<files>`); see
[Kavita's scanner docs](https://wiki.kavitareader.com/guides/scanner/) if
series come out split or merged.

Reader apps use the same address and port: `/api` skips Umbrel login and uses
Kavita's own accounts.

- OPDS: user settings → 3rd Party Clients → OPDS URL
  (`http://<umbrel>:5000/api/opds/<api key>`)
- Mihon/Tachiyomi: the Kavita extension, with the same OPDS URL.

Kavita has no Kobo sync like Komga's.
