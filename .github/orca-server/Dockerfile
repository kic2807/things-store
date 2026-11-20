# Orca's headless server (`orca serve`) for things-orca-server: the official
# orca-server-linux-x64.tar.gz release bundle (own Node runtime, no Electron)
# on Debian with the tools coding agents expect. Built by
# .github/workflows/build-orca-server.yml, which passes the release version
# and the SHA-256 GitHub lists for the asset.
#
# Agent CLIs (Claude Code, Codex, ...) are not baked in: they update
# themselves, so they are installed into the persistent home
# (~/.local, on PATH) after the app is installed. See the app README.
FROM debian:trixie-slim

ARG ORCA_VERSION
ARG ORCA_SHA256

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash build-essential ca-certificates curl gh git git-lfs gnupg jq less \
      nano nodejs npm openssh-client procps python3 python3-venv ripgrep \
      tzdata unzip xz-utils zip \
 && rm -rf /var/lib/apt/lists/*

RUN test -n "$ORCA_VERSION" && test -n "$ORCA_SHA256" \
 && curl -fsSL -o /tmp/orca.tgz \
      "https://github.com/stablyai/orca/releases/download/v${ORCA_VERSION}/orca-server-linux-x64.tar.gz" \
 && echo "${ORCA_SHA256}  /tmp/orca.tgz" | sha256sum -c - \
 && mkdir /opt/orca \
 && tar xzf /tmp/orca.tgz -C /opt/orca --strip-components=1 \
 && rm /tmp/orca.tgz \
 && grep -qx "orca ${ORCA_VERSION}" /opt/orca/VERSION \
 && ln -s /opt/orca/bin/orca-ide /usr/local/bin/orca

# tailcat (tailscale/tailcat), for the app's `tailcat` service: reaches the
# server through a tunnel without Tailscale on the client
# (/usr/local/bin/orca-tailcat). Pinned by hand: bump the version and the
# SHA-256 of tailcat_<v>_linux_amd64.tar.gz from the release's checksums.txt.
ARG TAILCAT_VERSION=0.7.0
ARG TAILCAT_SHA256=23c0b1887a5ec422f0d18a9c52b4f5357815febdaae738a1eb54036d10bd9ee6
RUN curl -fsSL -o /tmp/tailcat.tgz \
      "https://github.com/tailscale/tailcat/releases/download/v${TAILCAT_VERSION}/tailcat_${TAILCAT_VERSION}_linux_amd64.tar.gz" \
 && echo "${TAILCAT_SHA256}  /tmp/tailcat.tgz" | sha256sum -c - \
 && tar xzf /tmp/tailcat.tgz -C /usr/local/bin tailcat \
 && rm /tmp/tailcat.tgz \
 && tailcat --version | grep -qx "v${TAILCAT_VERSION}"
COPY orca-tailcat /usr/local/bin/orca-tailcat

# Login shells (`bash -l`, and terminals that start one) get their PATH from
# /etc/profile, which drops ~/.local/bin, and the home in app data has no
# ~/.profile to add it back: agents installed there (claude, codex) would not
# be found.
RUN printf '%s\n' 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac' \
      'export PATH' > /etc/profile.d/orca-local-bin.sh

# Same UID/GID as the umbrel user, so app-data stays owned by it.
RUN groupadd -g 1000 orca \
 && useradd -u 1000 -g 1000 -m -d /home/orca -s /bin/bash orca

USER orca
WORKDIR /home/orca
ENV HOME=/home/orca \
    SHELL=/bin/bash \
    LANG=C.UTF-8 \
    NPM_CONFIG_PREFIX=/home/orca/.local \
    PATH=/home/orca/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 6768
# Listen on every interface of the container (the published port decides
# what reaches it). Pairing stays on: --no-pairing also makes `orca pair`
# refuse. Pair with `orca pair --address <host>` (the startup link says 127.0.0.1).
# --supervise restarts the server in-process and keeps terminals alive.
CMD ["orca", "serve", "--port", "6768", "--bind", "0.0.0.0", "--supervise"]
