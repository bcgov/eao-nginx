# Migration Guide: DeploymentConfig → Deployment

This guide explains how to migrate from the legacy S2I + DeploymentConfig pattern to the modern Dockerfile + Helm + Deployment pattern.

## Background

**Why Migrate?**
- DeploymentConfig is deprecated in OpenShift 4.14+, will be removed in future versions
- S2I builder (`s2i-nginx`) is unmaintained and has security vulnerabilities
- Jenkins CI/CD may be decommissioned by bcgov
- Modern pattern aligns with eagle-api, eagle-admin, eagle-public

**What Changes?**
| Old Pattern | New Pattern |
|-------------|-------------|
| S2I build with `s2i-nginx:latest` | Multi-stage Dockerfile with `nginx:1.27-alpine` |
| DeploymentConfig | Kubernetes Deployment |
| OpenShift Templates (`.json`) | Helm charts |
| Jenkins pipeline | GitHub Actions workflows |
| Manual `oc rollout latest` | Automatic image trigger annotation |

---

## Pre-Migration Checklist

Before starting migration, verify:

1. **Current State:**
   ```bash
   # Check existing DeploymentConfig
   oc get dc rproxy -n 6cdc9e-dev -o yaml > /tmp/rproxy-dc-backup.yaml
   
   # Check current image
   oc get istag rproxy:dev -n 6cdc9e-tools
   
   # Test current deployment works
   curl -s https://eagle-dev.apps.silver.devops.gov.bc.ca/nginx_status
   ```

2. **Backup Critical Data:**
   ```bash
   # Export current environment variables
   oc get dc rproxy -n 6cdc9e-dev -o jsonpath='{.spec.template.spec.containers[0].env}' | jq '.' > /tmp/rproxy-env-vars.json
   
   # Export current Route configuration
   oc get route eagle-api -n 6cdc9e-dev -o yaml > /tmp/rproxy-route-backup.yaml
   ```

3. **GitHub Secrets:**
   Ensure repository has required secrets:
   - `OPENSHIFT_SERVER`: https://api.silver.devops.gov.bc.ca:6443
   - `OPENSHIFT_TOKEN`: Service account token with admin access to 6cdc9e-* namespaces

---

## Migration Steps

### Phase 1: Setup (No Impact on Running System)

**1.1 Create BuildConfig for Dockerfile**

The new workflow uses `oc start-build` with `--from-dir=.` instead of S2I. First, create a Docker build config:

```bash
oc create -f - <<EOF
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: rproxy
  namespace: 6cdc9e-tools
  labels:
    app: rproxy
spec:
  output:
    to:
      kind: ImageStreamTag
      name: rproxy:latest
  source:
    type: Binary
    binary: {}
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
  triggers: []
EOF
```

**Note**: The existing ImageStream `rproxy` should remain unchanged.

**1.2 Verify Helm Chart**

```bash
# Validate Helm chart syntax
helm lint ./helm/rproxy

# Test template rendering (dry-run)
helm template rproxy ./helm/rproxy \
  -f ./helm/rproxy/values-dev.yaml \
  --debug
```

---

### Phase 2: Dev Environment Migration

**2.1 Build New Image**

Trigger the new Docker build:

```bash
# From local eao-nginx repository
cd /root/repos/eao-nginx

# Build and push to tools namespace
oc start-build rproxy \
  --from-dir=. \
  --follow \
  --wait \
  -n 6cdc9e-tools

# Verify build succeeded
oc get builds -n 6cdc9e-tools | grep rproxy | tail -1
```

**2.2 Tag for Dev**

```bash
# Tag new image as dev-new (temporary tag for testing)
oc tag rproxy:latest rproxy:dev-new -n 6cdc9e-tools
```

**2.3 Deploy New Helm Release (Blue-Green)**

Deploy new Deployment alongside existing DeploymentConfig:

```bash
# Deploy with temporary name
helm install rproxy-new ./helm/rproxy \
  -n 6cdc9e-dev \
  -f ./helm/rproxy/values-dev.yaml \
  --set fullnameOverride=rproxy-new \
  --set image.tag=dev-new \
  --set route.enabled=false
```

**2.4 Test New Deployment**

```bash
# Check pods started successfully
oc get pods -l app.kubernetes.io/name=rproxy -n 6cdc9e-dev

# Port-forward to test locally
oc port-forward -n 6cdc9e-dev deployment/rproxy-new 8080:8080

# In another terminal, test endpoints
curl http://localhost:8080/nginx_status
curl -I http://localhost:8080/api/config
curl -I http://localhost:8080/admin/
```

**2.5 Cutover Route**

Once verified, switch the Route to the new Service:

```bash
# Patch route to use new service
oc patch route eagle-api -n 6cdc9e-dev --type='json' \
  -p='[{"op": "replace", "path": "/spec/to/name", "value": "rproxy-new"}]'

# Verify route works
curl -s https://eagle-dev.apps.silver.devops.gov.bc.ca/api/config | jq .ENVIRONMENT
```

**2.6 Cleanup Old DeploymentConfig**

After verifying the new deployment works for 24-48 hours:

```bash
# Scale down old DeploymentConfig
oc scale dc/rproxy --replicas=0 -n 6cdc9e-dev

# Wait 24 hours, verify no issues

# Delete old DeploymentConfig
oc delete dc rproxy -n 6cdc9e-dev

# Rename new deployment to standard name
helm uninstall rproxy-new -n 6cdc9e-dev
helm install rproxy ./helm/rproxy \
  -n 6cdc9e-dev \
  -f ./helm/rproxy/values-dev.yaml \
  --set image.tag=dev \
  --set route.enabled=false

# Update route to use final service name
oc patch route eagle-api -n 6cdc9e-dev --type='json' \
  -p='[{"op": "replace", "path": "/spec/to/name", "value": "rproxy"}]'
```

---

### Phase 3: Test Environment Migration

**3.1 Create Release and Deploy**

```bash
# Trigger GitHub Actions workflow
gh workflow run "Deploy to Test" \
  --repo bcgov/eao-nginx \
  --field version=v1.0.0
```

**3.2 Follow Same Blue-Green Process**

Repeat steps 2.3-2.6 for test environment (`6cdc9e-test`).

---

### Phase 4: Production Migration

**Schedule downtime window** (5-10 minutes) for production cutover.

**4.1 Deploy to Prod**

```bash
gh workflow run "Deploy to Prod" \
  --repo bcgov/eao-nginx \
  --field version=v1.0.0
```

**4.2 Blue-Green Cutover**

Follow steps 2.3-2.6 for production environment (`6cdc9e-prod`).

---

## Rollback Procedures

### Rollback During Migration (Before Deleting DC)

```bash
# Switch route back to old service
oc patch route eagle-api -n 6cdc9e-dev --type='json' \
  -p='[{"op": "replace", "path": "/spec/to/name", "value": "rproxy"}]'

# Old DeploymentConfig still running, no data loss
```

### Rollback After Migration Complete

```bash
# Use Helm rollback
helm rollback rproxy -n 6cdc9e-dev

# Or deploy previous image tag
helm upgrade rproxy ./helm/rproxy \
  -n 6cdc9e-dev \
  -f ./helm/rproxy/values-dev.yaml \
  --set image.tag=<previous-tag>
```

---

## Verification

After migration, verify all routes work:

```bash
# Test all endpoints
curl -s https://eagle-dev.apps.silver.devops.gov.bc.ca/ -o /dev/null -w "%{http_code}\n"
curl -s https://eagle-dev.apps.silver.devops.gov.bc.ca/admin/ -o /dev/null -w "%{http_code}\n"
curl -s https://eagle-dev.apps.silver.devops.gov.bc.ca/api/config | jq .ENVIRONMENT
curl -s https://eagle-dev.apps.silver.devops.gov.bc.ca/analytics/health
curl -s https://eagle-dev.apps.silver.devops.gov.bc.ca/nginx_status

# Verify Deployment (not DeploymentConfig)
oc get deployment rproxy -n 6cdc9e-dev
oc get dc rproxy -n 6cdc9e-dev  # Should return "not found"

# Check image trigger works
oc describe deployment rproxy -n 6cdc9e-dev | grep image.openshift.io/triggers
```

---

## Post-Migration Cleanup

**Remove Legacy Resources:**

```bash
# Delete old BuildConfig (if using new Docker build)
oc delete bc rproxy -n 6cdc9e-tools --dry-run=client  # Verify first
oc delete bc rproxy -n 6cdc9e-tools

# Archive legacy OpenShift templates
mkdir -p openshift/templates/archived
git mv openshift/templates/*.json openshift/templates/archived/

# Archive Jenkinsfile
git mv Jenkinsfile Jenkinsfile.archived

# Update .gitignore
echo "openshift/templates/archived/" >> .gitignore
echo "Jenkinsfile.archived" >> .gitignore

# Commit cleanup
git add .
git commit -m "chore: archive legacy S2I and DeploymentConfig resources"
git push origin develop
```

---

## Troubleshooting

**Build fails with "Dockerfile not found":**
- Ensure you're running `oc start-build` with `--from-dir=.` from repository root

**Deployment stuck in Pending:**
- Check events: `oc describe deployment rproxy -n 6cdc9e-dev`
- Check image pull: `oc get events -n 6cdc9e-dev | grep rproxy`

**Health probes failing:**
- Check `/nginx_status` endpoint works: `oc exec deployment/rproxy -n 6cdc9e-dev -- curl http://localhost:8080/nginx_status`
- Verify nginx config: `oc exec deployment/rproxy -n 6cdc9e-dev -- nginx -t`

**Environment variables not applied:**
- Check Deployment env: `oc get deployment rproxy -n 6cdc9e-dev -o jsonpath='{.spec.template.spec.containers[0].env}' | jq '.'`
- Verify values file: `cat helm/rproxy/values-dev.yaml`

**504 Gateway Timeout on /admin/ route:**
- Usually caused by NetworkPolicy requiring `role: rproxy-eagle-epic` label
- See [Troubleshooting Wiki](https://github.com/bcgov/eagle-dev-guides/wiki/Troubleshooting#504-gateway-timeout-on-admin-route) for detailed diagnosis

---

## Timeline

**Recommended migration timeline:**

| Phase | Duration | Notes |
|-------|----------|-------|
| Phase 1: Setup | 1-2 hours | No user impact |
| Phase 2: Dev Migration | 1-2 days | Blue-green, can rollback easily |
| Phase 3: Test Migration | 1-2 days | Verify 24-48 hours before prod |
| Phase 4: Prod Migration | 5-10 min downtime | Schedule maintenance window |
| Cleanup | 1 hour | Archive old resources |

**Total**: ~1 week for cautious migration with validation at each step.

---

## Support

Questions or issues during migration:
- [Open GitHub Issue](https://github.com/bcgov/eao-nginx/issues)
- Slack: `#falcon-general` channel
- [Eagle Dev Guides Wiki](https://github.com/bcgov/eagle-dev-guides/wiki)
