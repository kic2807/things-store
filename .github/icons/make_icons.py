#!/usr/bin/env python3
"""Build square app icons for the store from dashboard-icons logos.

Umbrel shows app icons as full squares and rounds the corners itself; the
dashboard-icons SVGs are transparent logos, which look like floating circles.
This wraps each logo in a 256x256 square with a background colour and writes
<app>/icon.svg. Run from the repo root: python3 .github/icons/make_icons.py
"""

import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/{}.svg"

# app folder: (dashboard-icons name or full SVG URL, background, logo size as share of 256)
ICONS = {
    "things-caddy": ("caddy", "#ffffff", 0.72),
    "things-cloudflare-ddns": ("cloudflare", "#1d2230", 0.74),
    "things-stump": ("stump", "#f4e6de", 1.0),
    "things-pocket-id": ("pocket-id", "#000000", 1.0),
    "things-tinyauth": ("tinyauth", "#eef3f8", 0.74),
    "things-transmission-vpn": ("private-internet-access", "#ffffff", 0.68),
    "things-gitea-act-runner": ("gitea", "#ffffff", 0.74),
    "things-sideimpactor": ("apple", "#ffffff", 0.6),
    "things-immich-ml": ("https://cdn.jsdelivr.net/gh/selfhst/icons/svg/immich-light.svg", "#4250af", 0.66),
    "things-cleanuparr": ("https://raw.githubusercontent.com/Cleanuparr/Cleanuparr/main/Logo/logo.svg", "#efe6f7", 0.8),
}


def wrap(svg: str, background: str, share: float) -> str:
    svg = re.sub(r"<\?xml[^>]*\?>", "", svg).strip()
    head = re.match(r"<svg\b([^>]*)>", svg)
    attrs = head.group(1)
    view_box = re.search(r'viewBox="([^"]+)"', attrs)
    if view_box:
        view_box = view_box.group(1)
    else:  # some logos only set width/height (e.g. stump)
        size = lambda name: re.search(rf'\b{name}="([\d.]+)', attrs).group(1)
        view_box = f"0 0 {size('width')} {size('height')}"
    inner = svg[head.end():svg.rindex("</svg>")]
    size = 256 * share
    offset = (256 - size) / 2
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        'viewBox="0 0 256 256" width="256" height="256">'
        f'<rect width="256" height="256" fill="{background}"/>'
        f'<svg x="{offset:.1f}" y="{offset:.1f}" width="{size:.1f}" height="{size:.1f}" '
        f'viewBox="{view_box}" preserveAspectRatio="xMidYMid meet">{inner}</svg></svg>\n'
    )


for app, (name, background, share) in ICONS.items():
    if not (ROOT / app).is_dir():
        continue
    url = name if name.startswith("https://") else SRC.format(name)
    with urllib.request.urlopen(url, timeout=30) as resp:
        svg = resp.read().decode()
    (ROOT / app / "icon.svg").write_text(wrap(svg, background, share))
    print(f"{app}/icon.svg  <- {url} on {background}")
