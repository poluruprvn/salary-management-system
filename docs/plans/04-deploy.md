# Salary management: deploy

## Context

The app runs only on a laptop today. This plan puts the API and the SPA on a single Hetzner server with Kamal 2. The Rails image is already there: the Dockerfile builds it, `bin/docker-entrypoint` runs `db:prepare` when the server starts, and `/healthz` answers health checks. Kamal itself is missing: there is no gem, no `config/deploy.yml` and no `.kamal/secrets`.

This is an assignment, so production is a demo and needs the demo data. `db/seeds.rb` returned straight away outside development and test, so a fresh deploy would have had no login and no employees.

## Decisions

- **One server, two Kamal apps.** `sms` is the API. `sms-web` is the SPA. CLAUDE.md treats them as separate deploy artifacts, so each has its own image, its own `config/deploy.yml` and its own `kamal deploy`. They share the host and the single kamal-proxy.
- **One hostname, split by path.** Both apps set `host: <domain>`. The API adds `path_prefix: /api` and `strip_path_prefix: false`, since its routes already start with `/api`. kamal-proxy sends `/api/*` to Rails and everything else to the SPA. The browser sees one origin, so no CORS preflight and one certificate.
- **kamal-proxy splits the paths, not Caddy.** Caddy has no stable name to proxy `/api` to. Kamal names the API container `sms-web-<version>` (service `sms`, role `web`, version) and gives it no network alias, so the upstream changes on every deploy. Going around kamal-proxy would also lose its gapless rollout for the API.
- **Postgres is a Kamal accessory on the same host.** `postgres:18-alpine`, as in `compose.yaml`, because the schema calls `uuidv7()`, its data in the host directory `~/sms-db/data`, and no public port. Rails reaches it as `sms-db` over the `kamal` Docker network. A managed database costs more than the server it would serve.
- **TLS ends at kamal-proxy.** On a shared host, kamal-proxy takes TLS from the root path app, so only the SPA sets `ssl: true`. Deploy the SPA first. Production already sets `assume_ssl` and `force_ssl`, so Rails treats proxied requests as HTTPS. The proxy's health check reaches `/healthz` without being redirected.
- **The SPA gets its API URL at build time.** Vite bakes `VITE_API_URL` into the bundle, so it goes in as a build arg, not a runtime env var. Changing the API host means rebuilding the SPA.
- **Caddy serves only the SPA.** One `Caddyfile`: serve `dist/`, fall back to `index.html` for client-side routes, and cache the hashed files under `/assets` for a long time. Everything else is `no-cache`, and a missing asset is a 404, so a stale `index.html` never pins the app to deleted assets. kamal-proxy already handles TLS, so Caddy listens on plain `:80`.
- **Production runs the full seed.** The `Rails.env.local?` guard goes, and `faker` moves to the default Gemfile group. `db:prepare` seeds an empty database on first boot: 10,000 employees took 9 seconds to healthy in a local container, and `deploy_timeout: 60` leaves room on a small box.
- **The HR login comes from secrets.** `SEED_HR_EMAIL` and `SEED_HR_PASSWORD` are Kamal secrets, so the demo does not ship with `password`. A re-run never overwrites an existing user.
- **Hosts and accounts come from the shell.** Both `deploy.yml` files read `KAMAL_HOST` and `KAMAL_SERVER_IP` through ERB, so no IP is committed.
- **No image registry account.** Both apps use `registry.server: localhost:5555`. Kamal runs that registry on the laptop and pushes to the server through an SSH tunnel, so there is no GHCR login or token.
- **Images are built for `amd64`.** Hetzner's CX and CPX lines are x86. An ARM (CAX) box would need `arch: arm64` and a remote builder or QEMU.

---

## Phase 1: Server

- Create a Hetzner Cloud server (CX22 is enough) running Ubuntu 24.04, with your SSH key.
- Add a Hetzner firewall that allows only 22, 80 and 443.
- Point the `<domain>` A record at it.
- Kamal installs Docker on first `setup`. Nothing else goes on the box by hand.

**Verify:** `ssh root@<ip>` works, and `dig <domain>` returns the server's IP.

---

## Phase 2: Seeds in production

`db/seeds.rb`, `Gemfile`, `spec/db/seeds_spec.rb`.

- Remove `return unless Rails.env.local?` and the spec that asserted it.
- Move `faker` out of the development and test group.

**Verify:** `bundle exec rspec spec/db/seeds_spec.rb` passes. The production image, run against an empty `postgres:18-alpine`, boots, seeds 10,000 employees, and signs in the HR account from the env.

---

## Phase 3: API on Kamal

Run this after Phase 4 on a fresh server: the API's `/api` route needs the SPA's root route to exist for TLS.

`Gemfile`, `config/deploy.yml`, `.kamal/secrets`.

- Add `gem "kamal", require: false` and run `bundle exec kamal init`. Delete the hooks it generates unless we use one.
- `config/deploy.yml`: the `/api` proxy with the `/healthz` check, the local registry, `amd64`, `deploy_timeout: 60`, the database env, the secrets below, and the Postgres accessory. Read the file itself for the values.
- `.kamal/secrets` reads the values from the shell, and never holds them itself:

```sh
RAILS_MASTER_KEY=$(cat config/master.key)
DATABASE_PASSWORD=$SMS_DATABASE_PASSWORD
POSTGRES_PASSWORD=$SMS_DATABASE_PASSWORD
SEED_HR_EMAIL=$SMS_HR_EMAIL
SEED_HR_PASSWORD=$SMS_HR_PASSWORD
```

- `RAILS_MASTER_KEY` unlocks `secret_key_base`, which also signs the JWTs. Rotating it logs everyone out.

**Verify:** `bin/kamal config` renders with no errors. `bin/kamal setup` boots the accessory, then the app. `/healthz` is outside `/api`, so kamal-proxy checks it directly on the container and it is not public. `bin/kamal app exec "curl -s localhost:3000/healthz"` returns 200. `bin/kamal app logs` shows lograge JSON lines. The seeded HR account can log in with `POST /api/v1/auth/sign_in` and gets a token.

---

## Phase 4: SPA on Kamal

`web/Dockerfile`, `web/Caddyfile`, `web/.dockerignore`, `web/config/deploy.yml`.

- `web/Dockerfile`: a `node:22-slim` stage runs `npm ci` and `npm run build`, with `ARG VITE_API_URL`. The final stage is `caddy:2-alpine`, and it copies in `dist/` and the `Caddyfile`.
- `web/Caddyfile`: see the Caddy decision above.
- `web/.dockerignore`: `node_modules`, `dist`.
- `web/config/deploy.yml`: `service: sms-web`, the same server and registry, `proxy.host: <domain>` with no path prefix, `app_port: 80`, `healthcheck.path: /`, and `builder.args: { VITE_API_URL: https://<domain> }`. No env, no accessories.
- No `web/.kamal/secrets`: the SPA has no secrets.

**Verify:** `cd web && ../bin/kamal setup`. `https://<domain>` loads, a hard reload on a deep link such as `/employees/1` still serves the app, and login works. The network tab shows no `OPTIONS` preflight.

---

## Phase 5: Day two

- Deploy: `bin/kamal deploy` at the repo root for the API, and `../bin/kamal deploy` in `web/` for the SPA. Each rolls out with no downtime behind the proxy.
- Rollback: `bin/kamal rollback <version>`.
- Kamal builds from a clone of the last commit, not the working tree. Commit before you deploy.
- Migrations run through `db:prepare` on boot. The old container keeps serving until the new one is healthy, so a migration has to work with the code that is still running.
- Backups: a nightly `pg_dump` from the host through `bin/kamal accessory exec db`, sent off the box, or Hetzner's server snapshots. Pick one before real data goes in.

**Verify:** make a trivial change, deploy, and confirm `bin/kamal app details` shows the new version and `/healthz` never failed during the rollout.

---

## Open

- Backups, see Phase 5.
