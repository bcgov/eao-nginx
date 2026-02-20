# =============================================================================
# eao-nginx (rproxy) - Reverse Proxy for EPIC Platform
# =============================================================================
# Modern Dockerfile-based deployment replacing S2I builds and DeploymentConfig.
# Proxies traffic to eagle-public, eagle-admin, eagle-api, penguin-analytics.
#
# Build: docker build -t rproxy .
# Run:   docker run -p 8080:8080 -e NGINX__EPIC__PROXY__API=http://eagle-api:3000 rproxy
# =============================================================================

FROM nginx:1.27-alpine

# Update Alpine packages to latest security patches
RUN apk upgrade --no-cache

# Labels for OpenShift compatibility
LABEL io.openshift.expose-services="8080:http" \
      io.openshift.tags="nginx,rproxy,reverse-proxy" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      name="bcgov/eao-nginx" \
      summary="EPIC Reverse Proxy" \
      description="nginx reverse proxy for Environmental Assessment Office's EPIC platform"

# Install gettext for envsubst and openssl for htpasswd generation
RUN apk add --no-cache gettext openssl

# Create nginx directories and set permissions for OpenShift (arbitrary UID)
RUN mkdir -p /var/cache/nginx /var/run /etc/nginx/templates && \
    chown -R nginx:0 /var/cache/nginx /var/run /var/log/nginx /etc/nginx && \
    chmod -R g+rwx /var/cache/nginx /var/run /var/log/nginx /etc/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:0 /var/run/nginx.pid && \
    chmod g+rw /var/run/nginx.pid

# Copy main nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy server configuration template (will be processed by envsubst at runtime)
COPY conf.d/server.conf.tmpl /etc/nginx/templates/default.conf.template

# Copy HTTP Basic Auth htpasswd generation script (runs at container startup)
COPY generate-htpasswd.sh /docker-entrypoint.d/10-generate-htpasswd.sh

# Make startup script executable
RUN chmod +x /docker-entrypoint.d/10-generate-htpasswd.sh

# Expose port 8080 (OpenShift doesn't allow privileged ports like 80)
EXPOSE 8080

# Run as nginx user (OpenShift will override UID but keep group 0)
USER nginx

# Default command (inherited from base image, runs nginx with envsubst processing)
# nginx base image automatically processes templates in /etc/nginx/templates/
