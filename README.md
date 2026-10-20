# eao-nginx (rproxy)

Reverse proxy for the EPIC platform. Routes traffic between eagle-public, eagle-api and the analytics API.

## Documentation

See the **[Reverse Proxy Configuration](https://github.com/bcgov/eagle-dev-guides/wiki/Reverse-Proxy-Configuration)** wiki page for:
- Routing configuration
- Environment variables
- Deployment procedures
- Troubleshooting

## Quick Reference

| Setting | Value |
|---------|-------|
| Base Image | nginx:1.27-alpine |
| Port | 8080 |

## State

rproxy runs in dev only: 1 replica, serving `/` on `eagle-dev.apps.silver.devops.gov.bc.ca` through Route `eagle-public` and proxying to the Azure test beta site. The test release is uninstalled and the prod Deployment is at 0 replicas; both values files set `replicaCount: 0`. Public traffic goes to Azure Front Door (`eagle-edge`).

## Operations notes

- Upstream names resolve once, when nginx loads its config. If an upstream IP moves, requests return 502 while the probes stay green. Run `oc rollout restart deploy/rproxy`.
- `connect() to [2603:...]:443 failed (101: Network unreachable)` in the error log is expected. The Front Door AAAA record is unreachable from the cluster, and nginx retries over IPv4.
- `/api/config`, including `SEARCH_API_PATH`, comes from the `Config` document in eagle-api's Mongo, not from chart values. Do not add `searchApiPath` to the values files.
- The chart keeps env vars that older image tags expand. The chart-vs-tags guard in `pr.yaml` fails the PR if a released tag at or above `MIN_TAG` needs a variable the chart does not set.

## Deploy

```bash
# Dev (auto on push to master)
gh workflow run deploy-to-dev.yaml

# Test/Prod (manual with version)
gh workflow run deploy-to-test.yaml -f version=v1.0.0
gh workflow run deploy-to-prod.yaml -f version=v1.0.0
```

## License

See [LICENSE](LICENSE)

