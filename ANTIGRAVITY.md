# eao-nginx (rproxy) Instructions

Reverse proxy for the EPIC platform.

## Configuration Setup

- **Branch**: `master` (NOT develop)
- **Base Image**: `nginx:1.27-alpine`
- **Port**: 8080

## CRITICAL Mandates

### Variable Substitution
- Uses `envsubst` for variables in `server.conf.tmpl`. Variables use `__` namespace separator (e.g., `NGINX__EPIC__PROXY__API`).
- **Host Header**: Use `$host` instead of `$http_host` to avoid double-prefixing by `envsubst`.

### Routing & Redirects
- **Trailing Slashes**: `location /admin/` only matches with the slash. Explicitly redirect `/admin` to `/admin/` using `$host` to avoid port exposure.
- **Legacy Analytics**: The `/api/analytics` location block MUST come before the general `/api` block to ensure correct priority.

### Runtime Config
- **Dev only.** Proxies `/api/config` to eagle-api, which serves it from a Config document in Mongo. Edit the document, not the ConfigMap; propagation is up to ~2 min (`max-age=60`, honoured by rproxy's cache and again by the browser), not instant. Test and prod still serve the ConfigMap, where `oc edit configmap` remains the instant lever.
- Rollback is **re-tagging the previous image** — `oc tag rproxy:<prev-sha> rproxy:dev -n 6cdc9e-tools`. `server.conf.tmpl` is baked in at `Dockerfile:39`, so re-adding the `alias` block is a code change plus a build plus a deploy, not a rollback. The `rproxy-config` ConfigMap and its mount stay for one release so the re-tagged image has something to serve.

## Deployment

- **Helm**: Release name `rproxy`.
- **Basic Auth**: Enabled in dev/test via `httpBasic.enabled`. Inject credentials at deploy time.
