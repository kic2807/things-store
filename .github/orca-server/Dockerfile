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
# what reaches it); no pairing link in the logs: pair with `orca pair`.
# --supervise restarts the server in-process and keeps terminals alive.
CMD ["orca", "serve", "--port", "6768", "--bind", "0.0.0.0", "--no-pairing", "--supervise"]
