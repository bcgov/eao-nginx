# eao-nginx
Nginx configuration for the Environmental Assessment Office's EPIC

## Example rollout usage

### nginx proxy deployment for esm-dev environment:
```
oc process -f https://raw.githubusercontent.com/bcgov/esm-server/master/openshift/templates/rproxy-build-template.json -v BUILDER_IMAGESTREAM_TAG=s2i-nginx:latest -v SOURCE_REPO
SITORY_URL=https://github.com/bcgov/eao-nginx -v NGINX_PROXY_URL=http://esm-dev:3000 -v NAME=rproxy | oc create -f -
```
### nginx proxy deployment for esm-master environment:

```
oc process -f https://raw.githubusercontent.com/bcgov/esm-server/master/openshift/templates/rproxy-environment-template.json -v APPLICATION_DOMAIN=esm-master.pathfinder.gov.bc.c
a -v APP_DEPLOYMENT_TAG=latest -v APP_IMAGE_NAMESPACE=esm APP_IMAGE_NAME=rproxy -v NAME=rproxy-master NGINX__EPIC_ADMIN__SERVER_NAME=esm-master.pathfinder.gov.bc.ca | oc create -f -
```

