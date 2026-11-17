# xess-xmx-linux (github.com/HHHHanasak1/xess-xmx-linux) for
# things-steam-headless: XeSS super resolution and frame generation on the
# XMX units of Intel Arc GPUs under Proton. The image holds one upstream
# release, unpacked, and a one-shot script that copies it into app data.
# Built by .github/workflows/build-xess-xmx.yml, which passes the release tag
# and the SHA-256 GitHub lists for its zip.
#
# Intel's compiler and XeSS SDK and AMD's FidelityFX files are not baked in
# (their licenses are their own): the package's install.sh downloads them once
# on the Umbrel, each checked against a SHA-256 pinned in the package.
FROM debian:trixie-slim

ARG XESS_XMX_RELEASE
ARG XESS_XMX_SHA256

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*

RUN test -n "$XESS_XMX_RELEASE" && test -n "$XESS_XMX_SHA256" \
 && curl -fsSL -o /tmp/x.zip \
      "https://github.com/HHHHanasak1/xess-xmx-linux/releases/download/${XESS_XMX_RELEASE}/xess-xmx-linux-${XESS_XMX_RELEASE}.zip" \
 && echo "${XESS_XMX_SHA256}  /tmp/x.zip" | sha256sum -c - \
 && unzip -q /tmp/x.zip -d /tmp/x \
 && mv "/tmp/x/xess-xmx-linux-${XESS_XMX_RELEASE}" /pkg \
 && rm -rf /tmp/x /tmp/x.zip \
 && test -x /pkg/install.sh \
 && echo "${XESS_XMX_RELEASE}" > /pkg/.release

COPY stage.sh /stage.sh
CMD ["/bin/sh", "/stage.sh"]
