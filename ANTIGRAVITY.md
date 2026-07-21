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
- Serves `/api/config` from the `rproxy-config` ConfigMap. Changes can be made live via `oc edit configmap`.

## Deployment

- **Helm**: Release name `rproxy`.
- **Basic Auth**: Enabled in dev/test via `httpBasic.enabled`. Inject credentials at deploy time.
