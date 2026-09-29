# saashup/flowg

Saashup's custom FlowG image, used on **paashups** to collect every
container's logs (sent via Docker's `syslog` logging driver`). 
It boots with a pipeline, transformer and stream
already wired up — no manual setup through the Web UI afterwards.

## What it does differently from `linksociety/flowg`

`entrypoint.sh` starts `flowg-server` as usual,
waits for it to report healthy, then runs `paashup/provision.sh` against
that API before handing control over to the server:

- **`docker` transformer** — a VRL script that renames the fields FlowG's
  built-in syslog source fills in (`tag`, `hostname`, `content`, as sent by
  dockerd's `syslog` logging driver configured with
  `--log-opt tag="{{.Name}}"`) into stable names: `container`, `host`,
  `message`. Records that don't come from that source are left untouched.
- **`default` pipeline** — both built-in sources (`direct` and `syslog`) are
  routed through the `docker` transformer before landing in the `default`
  stream, instead of upstream's bare source-to-router wiring.
- **`default` stream** — configured with a bounded retention
  (`FLOWG_LOG_RETENTION_DAYS` / `FLOWG_LOG_RETENTION_SIZE_MB`) and
  `container`/`host` as indexed fields, so the Log Explorer can filter by
  container without a full scan.

## Environment variables

Baked in as defaults — override with `-e` only if you need something
different: `FLOWG_SYSLOG_PROTOCOL` (`udp`), `FLOWG_HTTP_MOUNT_PATH`
(`/logging`), `FLOWG_AUTH_INITIAL_USER` (`admin`),
`FLOWG_LOG_RETENTION_DAYS` (`14`), `FLOWG_LOG_RETENTION_SIZE_MB` (`0`,
disabled).

**`FLOWG_AUTH_INITIAL_PASSWORD` default is admin, change in production.

All the other upstream `FLOWG_*` variables (`FLOWG_SYSLOG_BIND_ADDRESS`,
`FLOWG_SYSLOG_INITIAL_ALLOWED_ORIGINS`, `FLOWG_MGMT_BIND_ADDRESS`, TLS
settings, clustering, ...) still work as documented in
[flowg's own README](https://github.com/link-society/flowg) — this image
only changes the defaults listed above and adds the seeding step.

## Traefik label to add manually

The router **rule** can't be baked at
build time (it needs the paashup's real domain, unknown until `docker run`);
everything else (`entrypoints`, service port, HTTPS-forwarding middleware) is
already in the image:

```bash
--label "traefik.http.routers.flowg.rule=Host(\`${BASE_DOMAIN}\`) && PathPrefix(\`/logging\`)"
```

## Local test

```bash
docker build -t flowg:test .
docker run -d --name flowg-test -p 15080:5080 -p 15514:5514/udp \
  -e FLOWG_AUTH_INITIAL_PASSWORD=admin \
  flowg:test
# UI/API: http://localhost:15080/logging (admin/saashup)
logger --server 127.0.0.1 --port 15514 --udp "hello from a container"
```

## Build & publish

Push a `vX.Y.Z` tag — `.github/workflows/docker-publish.yml` handles the
build + push.
