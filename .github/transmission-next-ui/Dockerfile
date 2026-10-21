# Transmission Next UI for things-transmission-vpn: upstream's release files
# (hisproc/transmission-next-ui) served by Caddy, with /transmission/rpc passed
# to the official Transmission app. Built by
# .github/workflows/build-transmission-next-ui.yml, which unpacks the release
# into site/.
FROM caddy:2.11.7-alpine
COPY Caddyfile /etc/caddy/Caddyfile
COPY site/ /srv/
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s CMD wget -qO /dev/null http://127.0.0.1:8080/ || exit 1
