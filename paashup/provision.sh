#!/bin/sh
#
# Seeds FlowG through its own REST API. Runs once the server is
# already up and healthy.
#
# Seed-once: bails out as soon as the "docker" transformer already exists,
# so it never overwrites a pipeline/stream a user has since edited by hand
# through the Web UI.

set -eu

: "${FLOWG_HTTP_BIND_ADDRESS:=:5080}"
: "${FLOWG_HTTP_MOUNT_PATH:=/}"
: "${FLOWG_AUTH_INITIAL_USER:=admin}"
: "${FLOWG_AUTH_INITIAL_PASSWORD:?}"
: "${FLOWG_LOG_RETENTION_DAYS:=14}"
: "${FLOWG_LOG_RETENTION_SIZE_MB:=0}"

port="${FLOWG_HTTP_BIND_ADDRESS##*:}"
mount="${FLOWG_HTTP_MOUNT_PATH%/}"
base_url="http://127.0.0.1:${port}${mount}/api/v1"

log() {
  echo "provision: $*" >&2
}

token="$(
  curl -fsS -X POST "${base_url}/auth/login" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg u "$FLOWG_AUTH_INITIAL_USER" --arg p "$FLOWG_AUTH_INITIAL_PASSWORD" \
          '{username: $u, password: $p}')" \
    | jq -r '.token'
)"

if [ -z "$token" ] || [ "$token" = "null" ]; then
  log "login as '${FLOWG_AUTH_INITIAL_USER}' failed, skipping"
  exit 1
fi

status="$(
  curl -s -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer ${token}" \
    "${base_url}/transformers/docker"
)"

if [ "$status" = "200" ]; then
  log "already seeded, nothing to do"
  exit 0
fi

log "seeding 'docker' transformer, 'default' pipeline and 'default' stream"

jq -n --rawfile script /opt/flowg/paashup/transformers/docker.vrl '{script: $script}' \
  | curl -fsS -X PUT "${base_url}/transformers/docker" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d @- >/dev/null

curl -fsS -X PUT "${base_url}/pipelines/default" \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -d @/opt/flowg/paashup/pipelines/default.json >/dev/null

jq -n \
  --argjson ttl "$((FLOWG_LOG_RETENTION_DAYS * 86400))" \
  --argjson size "$FLOWG_LOG_RETENTION_SIZE_MB" \
  '{config: {ttl: $ttl, size: $size, indexed_fields: ["container", "host"]}}' \
  | curl -fsS -X PUT "${base_url}/streams/default" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d @- >/dev/null

log "done"
