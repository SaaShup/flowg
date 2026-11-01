FROM linksociety/flowg:v0.64.0

RUN apk add --no-cache curl jq

ENV FLOWG_SYSLOG_PROTOCOL=udp

ENV FLOWG_HTTP_MOUNT_PATH=/logging \
    FLOWG_AUTH_INITIAL_USER=admin \
    FLOWG_LOG_RETENTION_DAYS=14 \
    FLOWG_LOG_RETENTION_SIZE_MB=0

ENV FLOWG_AUTH_INITIAL_PASSWORD="admin"

LABEL traefik.enable="true" \
      traefik.docker.network="traefik" \
      traefik.http.routers.flowg.entrypoints="http" \
      traefik.http.services.flowg.loadbalancer.server.port="5080" \
      traefik.http.middlewares.force-https-header.headers.customrequestheaders.X-Forwarded-Proto="https" \
      traefik.http.middlewares.force-https-header.headers.customrequestheaders.X-Forwarded-Port="443" \
      traefik.http.routers.flowg.middlewares="force-https-header" \
      prometheus_address="flowg:9113" \
      prometheus_scrape="true"

COPY paashup/ /opt/flowg/paashup/
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /opt/flowg/paashup/provision.sh

ENTRYPOINT ["/entrypoint.sh"]
