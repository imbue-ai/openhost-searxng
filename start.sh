#!/bin/sh
set -e

# OpenHost mounts persistent storage at OPENHOST_APP_DATA_DIR.
# SearXNG expects config in /etc/searxng/ and cache data in /var/cache/searxng/.
# We symlink these into the persistent directory so data survives container restarts.
PERSIST="${OPENHOST_APP_DATA_DIR:-/data}"

CONFIG_DIR="$PERSIST/config"
DATA_DIR="$PERSIST/data"

mkdir -p "$CONFIG_DIR" "$DATA_DIR"

# Symlink SearXNG directories to persistent storage
if [ "$CONFIG_DIR" != "/etc/searxng" ]; then
    rm -rf /etc/searxng
    ln -sf "$CONFIG_DIR" /etc/searxng
fi

if [ "$DATA_DIR" != "/var/cache/searxng" ]; then
    rm -rf /var/cache/searxng
    ln -sf "$DATA_DIR" /var/cache/searxng
fi

# Generate and persist a secret key across restarts
SECRET_KEY_FILE="$PERSIST/.secret_key"
if [ -f "$SECRET_KEY_FILE" ]; then
    SECRET_KEY=$(cat "$SECRET_KEY_FILE")
else
    SECRET_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '\n/+=' | head -c 64)
    echo -n "$SECRET_KEY" > "$SECRET_KEY_FILE"
fi

# Derive base_url from OpenHost environment variables
if [ -n "$OPENHOST_ZONE_DOMAIN" ]; then
    APP_SUBDOMAIN="${OPENHOST_APP_NAME:-searxng}"
    DOMAIN_NAME="${APP_SUBDOMAIN}.${OPENHOST_ZONE_DOMAIN}"

    case "$OPENHOST_ZONE_DOMAIN" in
        lvh.me|*.lvh.me|localhost|*.localhost)
            # Dev environment — use http with the router's external port
            ROUTER_PORT=""
            if [ -n "$OPENHOST_ROUTER_URL" ]; then
                ROUTER_PORT=$(echo "$OPENHOST_ROUTER_URL" | sed -n 's/.*:\([0-9]*\)$/\1/p')
            fi
            BASE_URL="http://${DOMAIN_NAME}${ROUTER_PORT:+:$ROUTER_PORT}/"
            ;;
        *)
            # Production — HTTPS on standard port
            BASE_URL="https://${DOMAIN_NAME}/"
            ;;
    esac
else
    DOMAIN_NAME="localhost"
    BASE_URL="http://localhost:3000/"
fi

# Write settings.yml if it doesn't already exist (first boot)
SETTINGS_FILE="/etc/searxng/settings.yml"
if [ ! -f "$SETTINGS_FILE" ]; then
    cat > "$SETTINGS_FILE" <<EOF
use_default_settings: true
server:
  base_url: "${BASE_URL}"
  secret_key: "${SECRET_KEY}"
  limiter: false
  image_proxy: true
  method: "GET"
ui:
  static_use_hash: true
EOF
else
    # Update base_url and secret_key in existing settings on restart
    # (domain may change between dev and prod)
    export SEARXNG_SECRET="$SECRET_KEY"
fi

# Always export base_url as env var (overrides settings.yml)
export SEARXNG_BASE_URL="$BASE_URL"
export SEARXNG_SECRET="$SECRET_KEY"

# Fix ownership for the searxng user inside the container
chown -R searxng:searxng "$PERSIST" 2>/dev/null || true
chown -R searxng:searxng /etc/searxng 2>/dev/null || true
chown -R searxng:searxng /var/cache/searxng 2>/dev/null || true

# Start Caddy in background — it rewrites Host from X-Forwarded-Host on
# port 3000, then proxies to SearXNG on port 8080.
caddy run --config /app/Caddyfile &

# Hand off to the official SearXNG entrypoint
exec /usr/local/searxng/dockerfiles/docker-entrypoint.sh
