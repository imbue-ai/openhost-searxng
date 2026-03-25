SearXNG privacy-respecting metasearch engine for OpenHost. Runs as a single Docker container:

- SearXNG latest (aggregates results from 70+ search engines)
- No external database required (uses file-based caching)
- Persistent config and data in OpenHost's app_data directory

## How it works

On first boot, the container:
1. Creates config and data directories in the OpenHost persistent storage
2. Generates and persists a secret key
3. Writes a `settings.yml` with the correct base_url derived from OpenHost environment variables
4. Starts SearXNG with sensible defaults (image proxy enabled, GET method for ease of use)

## Deploying

Deploy via the OpenHost router dashboard — point it at this repo. The app will be available at `{app_name}.{zone_domain}` via subdomain routing (e.g. `searxng.zack.host.imbue.com`).

## Data

All persistent data lives in `$OPENHOST_APP_DATA_DIR/`:
- `config/settings.yml` — SearXNG configuration
- `data/` — cache data (favicons, etc.)

## Resources

Needs ~256MB RAM and 0.25 CPU cores. The container image is ~180MB.

## Configuration

`start.sh` auto-configures SearXNG at runtime. Key settings:
- `base_url` derived from `OPENHOST_ZONE_DOMAIN` and `OPENHOST_APP_NAME`
- Image proxy enabled (proxies images through the instance for privacy)
- Limiter disabled (not needed behind OpenHost's auth)
- GET method (better UX for back button, link sharing, etc.)

To customize search engines or other settings, edit `config/settings.yml` in the app's data directory.

## Files

- `Dockerfile` — extends the official SearXNG image, adds Caddy
- `start.sh` — configures SearXNG via env vars and settings.yml, then launches it
- `Caddyfile` — rewrites Host header from X-Forwarded-Host for correct URL handling
- `openhost.toml` — OpenHost app manifest
