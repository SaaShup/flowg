#!/bin/sh
#
# Wraps flowg-server: starts it (as the unprivileged `flowg` user, same as
# upstream's own docker-entrypoint.sh), waits for it to report healthy, then
# runs paashup/provision.sh against its own REST API before handing control
# over to it. Kept as PID 1 so `docker stop`'s SIGTERM is forwarded to the
# actual server process.

set -eu

mkdir -p /data
chmod 0700 /data
chown -R flowg:flowg /data

su-exec flowg /usr/local/bin/flowg-server "$@" &
flowg_pid=$!

trap 'kill -TERM "$flowg_pid" 2>/dev/null || true' TERM INT

until flowg-health --pid "$flowg_pid" >/dev/null 2>&1; do
  kill -0 "$flowg_pid" 2>/dev/null || exit 1
  sleep 0.5
done

/opt/flowg/paashup/provision.sh || echo "entrypoint: provisioning failed, continuing without it" >&2

wait "$flowg_pid"
