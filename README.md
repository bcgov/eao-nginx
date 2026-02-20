# eao-nginx (rproxy)

Reverse proxy for the EPIC platform. Routes traffic between eagle-public, eagle-admin, eagle-api, and penguin-analytics services.

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
| Branch | `master` |

## Environments

| Environment | URL |
|-------------|-----|
| Dev | https://eagle-dev.apps.silver.devops.gov.bc.ca |
| Test | https://eagle-test.apps.silver.devops.gov.bc.ca |
| Prod | https://projects.eao.gov.bc.ca |

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

