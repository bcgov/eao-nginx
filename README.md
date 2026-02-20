# eao-nginx (rproxy)

Reverse proxy for the BC Environmental Assessment Office's EPIC platform. Routes traffic to eagle-public, eagle-admin, eagle-api, and penguin-analytics services.

## Architecture

- **Base Image**: `nginx:1.27-alpine`
- **Deployment**: Kubernetes `Deployment` via Helm charts
- **CI/CD**: GitHub Actions workflows
- **Port**: 8080 (OpenShift compatible)

## Quick Start

### Local Development

```bash
# Build image
docker build -t rproxy:latest .

# Run locally (requires backend services)
docker run -p 8080:8080 \
  -e NGINX__EPIC__PROXY__API=http://eagle-api:3000 \
  -e NGINX__EPIC__PROXY__ADMIN=http://eagle-admin:8080 \
  -e NGINX__EPIC__PROXY__ROOT=http://eagle-public:8080 \
  rproxy:latest
```

### OpenShift Deployment

**Deploy to Dev:**
```bash
# Builds and deploys automatically on push to develop branch
# Or manually trigger:
gh workflow run "Deploy to Dev" --repo bcgov/eao-nginx
```

**Deploy to Test:**
```bash
gh workflow run "Deploy to Test" --repo bcgov/eao-nginx --field version=v1.0.0
```

**Deploy to Prod:**
```bash
gh workflow run "Deploy to Prod" --repo bcgov/eao-nginx --field version=v1.0.0
```

### Manual Helm Deployment

```bash
# Deploy to dev
helm upgrade --install rproxy ./helm/rproxy \
  -n 6cdc9e-dev \
  -f ./helm/rproxy/values-dev.yaml

# Deploy to test
helm upgrade --install rproxy ./helm/rproxy \
  -n 6cdc9e-test \
  -f ./helm/rproxy/values-test.yaml \
  --set image.tag=test

# Deploy to prod
helm upgrade --install rproxy ./helm/rproxy \
  -n 6cdc9e-prod \
  -f ./helm/rproxy/values-prod.yaml \
  --set image.tag=prod
```

## Configuration

### Routing

| Path | Destination | Service |
|------|-------------|---------|
| `/` | eagle-public | Public frontend |
| `/admin/` | eagle-admin | Admin frontend |
| `/api` | eagle-api | API backend |
| `/analytics` | penguin-analytics | Analytics service |
| `/eguide` | eagle-api | E-guide service |
| `/nginx_status` | nginx | Health check endpoint |

### Environment Variables

Key environment variables (set via Helm values):

```yaml
NGINX__EPIC__SERVER_NAME: "eagle-dev.apps.silver.devops.gov.bc.ca"
NGINX__EPIC__PROXY__ROOT: "http://eagle-public:8080"
NGINX__EPIC__PROXY__API: "http://eagle-api:3000"
NGINX__EPIC__PROXY__ADMIN: "http://eagle-admin:8080"
NGINX__EPIC__PROXY__ANALYTICS: "http://penguin-analytics-api:3000"
```

See `helm/rproxy/values-*.yaml` for complete configuration.

## Environments

| Environment | Namespace | URL | Image Tag |
|------------|-----------|-----|-----------|
| Dev | `6cdc9e-dev` | https://eagle-dev.apps.silver.devops.gov.bc.ca | `dev` |
| Test | `6cdc9e-test` | https://eagle-test.apps.silver.devops.gov.bc.ca | `test` |
| Prod | `6cdc9e-prod` | https://projects.eao.gov.bc.ca | `prod` |

## Migration from Legacy DeploymentConfig

See [MIGRATION.md](MIGRATION.md) for detailed migration instructions from the legacy S2I + DeploymentConfig setup to the modern Dockerfile + Helm + Deployment pattern.

**Key Changes:**
- ✅ S2I builds → Multi-stage Dockerfile
- ✅ DeploymentConfig → Kubernetes Deployment
- ✅ OpenShift Templates → Helm charts
- ✅ Jenkins → GitHub Actions
- ✅ Health probes added
- ✅ Security scanning with Trivy

## Development

### Modifying nginx Configuration

Edit `conf.d/server.conf.tmpl` to modify routing rules. Variables in `${VARIABLE}` format are substituted at container startup using `envsubst`.

### Testing Changes

1. Create feature branch
2. Open pull request
3. PR checks validate nginx config, Helm chart, and Dockerfile
4. Merge to `develop` triggers automatic deployment to dev
5. Manual promotion to test and prod via GitHub Actions

## Troubleshooting

**Check pod logs:**
```bash
oc logs -l app.kubernetes.io/name=rproxy -n 6cdc9e-dev
```

**Check deployment status:**
```bash
oc get deployment rproxy -n 6cdc9e-dev
oc describe deployment rproxy -n 6cdc9e-dev
```

**Test nginx config:**
```bash
oc exec -n 6cdc9e-dev deployment/rproxy -- nginx -t
```

**Check health endpoint:**
```bash
curl https://eagle-dev.apps.silver.devops.gov.bc.ca/nginx_status
```

## License

See [LICENSE](LICENSE)

## Related Documentation

- [Eagle Dev Guides Wiki](https://github.com/bcgov/eagle-dev-guides/wiki)
- [Helm Charts Documentation](helm/rproxy/README.md)

