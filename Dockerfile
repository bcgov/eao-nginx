FROM nginx:1.27-alpine

RUN apk upgrade --no-cache

LABEL io.openshift.expose-services="8080:http" \
      io.openshift.tags="nginx,rproxy,reverse-proxy" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      name="bcgov/eao-nginx" \
      summary="EPIC Reverse Proxy" \
      description="nginx reverse proxy for Environmental Assessment Office's EPIC platform"

RUN apk add --no-cache gettext openssl

# OpenShift runs an arbitrary UID in group 0, so group 0 needs write access.
RUN mkdir -p /var/cache/nginx /var/run /etc/nginx/templates && \
    chown -R nginx:0 /var/cache/nginx /var/run /var/log/nginx /etc/nginx && \
    chmod -R g+rwx /var/cache/nginx /var/run /var/log/nginx /etc/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:0 /var/run/nginx.pid && \
    chmod g+rw /var/run/nginx.pid

COPY nginx.conf /etc/nginx/nginx.conf

# The base image entrypoint renders /etc/nginx/templates with envsubst at container start.
COPY conf.d/server.conf.tmpl /etc/nginx/templates/default.conf.template

COPY generate-htpasswd.sh /docker-entrypoint.d/10-generate-htpasswd.sh

RUN chmod +x /docker-entrypoint.d/10-generate-htpasswd.sh

# OpenShift does not allow privileged ports like 80.
EXPOSE 8080

# OpenShift overrides the UID but keeps group 0.
USER nginx
