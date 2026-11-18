# linksociety/flowg est distroless (pas de shell ni d'apk) et amd64 uniquement :
# on reprend ses binaires sur une Debian pour pouvoir installer curl et jq.
FROM --platform=linux/amd64 linksociety/flowg:v0.64.2 AS flowg

FROM --platform=linux/amd64 debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl jq gosu libssl3t64 libstdc++6 libgomp1 libzstd1 liblzma5 zlib1g \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/sbin/gosu /usr/local/bin/su-exec \
 && groupadd --system --gid 10001 flowg \
 && useradd --system --uid 10001 --gid flowg --no-create-home --shell /usr/sbin/nologin flowg

COPY --from=flowg /usr/local/bin/flowg-server /usr/local/bin/flowg-health /usr/local/bin/
COPY --from=flowg /usr/lib/x86_64-linux-gnu/libfdb_c.so /usr/lib/x86_64-linux-gnu/

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    FLOWG_SECRET_KEY= \
    FLOWG_VERBOSE=false \
    FLOWG_HTTP_BIND_ADDRESS=:5080 \
    FLOWG_HTTP_TLS_ENABLED=false \
    FLOWG_HTTP_TLS_CERT= \
    FLOWG_HTTP_TLS_KEY= \
    FLOWG_MGMT_BIND_ADDRESS=:9113 \
    FLOWG_MGMT_TLS_ENABLED=false \
    FLOWG_MGMT_TLS_CERT= \
    FLOWG_MGMT_TLS_KEY= \
    FLOWG_SYSLOG_PROTOCOL=udp \
    FLOWG_SYSLOG_BIND_ADDRESS=:5514 \
    FLOWG_SYSLOG_ALLOW_ORIGINS= \
    FLOWG_SYSLOG_TLS_ENABLED=false \
    FLOWG_SYSLOG_TLS_CERT= \
    FLOWG_SYSLOG_TLS_KEY= \
    FLOWG_SYSLOG_TLS_AUTH=false \
    FLOWG_BADGER_AUTH_DIR=/data/auth \
    FLOWG_BADGER_CONFIG_DIR=/data/config \
    FLOWG_BADGER_LOG_DIR=/data/logs

VOLUME /data

HEALTHCHECK --interval=5s --timeout=1s --retries=3 \
  CMD ["/usr/local/bin/flowg-health", "--pid", "1"]

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
