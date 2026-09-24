# SMS

Salary management system. A Rails 8.1 API-only backend, with a React 19 + Vite single-page app in [`web/`](web). The two are separate applications. They talk over HTTP and deploy independently.

## Requirements

- Ruby 3.4.10 (see `.ruby-version`)
- Headers the `pg` gem compiles against. On Debian/Ubuntu: `libpq-dev build-essential libyaml-dev pkg-config`
- Node.js `^20.19 || >=22.12` with npm, for `web/`
- Docker with Compose, which provides PostgreSQL 18. Or point `.env` at your own.

## Setup

```sh
cp .env.example .env                 # required: database.yml has no defaults
docker compose up -d --wait postgres # or point .env at your own Postgres
bin/setup --skip-server              # bundle install + db:prepare
```

`bin/setup` without `--skip-server` runs the setup steps and then execs the server, so it never returns. Use `--reset` to drop and recreate the database.

Gems install into `vendor/bundle`. Run Ruby tools through `bundle exec` or the `bin/` binstubs.

Frontend:

```sh
cd web && npm install
```

## Running

Two processes:

```sh
bin/dev                 # API on http://localhost:3000
cd web && npm run dev   # SPA on http://localhost:5173
```

`GET /healthz` checks the process and Postgres, returning 503 when the database is unreachable. `GET /readyz` adds a pending-migration check. No root route is defined. Nothing else is built yet: no models, no migrations, no resource endpoints.

## Tests

```sh
bundle exec rspec
bundle exec rspec spec/models/thing_spec.rb:42   # single file or example
```

`.rspec` loads only `spec_helper`. Each spec file must `require "rails_helper"` itself to pull in Rails. The suite uses its own database (`TEST_DATABASE_NAME`).

`factory_bot_rails`, `faker` and `shoulda-matchers` are available for test data and matchers. No specs and no `spec/factories/` exist yet, so `rspec` reports 0 examples.

## Checks

```sh
bin/ci                  # setup + rubocop + rspec + bundler-audit + brakeman + OpenAPI freshness
bin/rubocop -a          # autocorrect
cd web && npm run lint  # oxlint
cd web && npm run build # tsc -b && vite build
```

`bin/ci` starts with a `Setup` step that re-runs `bin/setup --skip-server`, so it also reinstalls gems and prepares the database. It passes `SEED_EMPLOYEE_COUNT=50`, because `db:prepare` seeds whenever it creates the database and a fresh checkout would otherwise seed the full set before linting. The last step regenerates `swagger/v1/openapi.yaml` from the request specs and fails if the committed copy differs.

## Configuration

Backend configuration comes from `.env`, loaded by dotenv and gitignored:

| Variable | Purpose |
| --- | --- |
| `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`, `DATABASE_PASSWORD` | Postgres connection; no defaults, all required |
| `DATABASE_NAME`, `TEST_DATABASE_NAME` | Development and test databases |
| `CORS_ORIGINS` | Comma-separated allowed origins, defaults to `http://localhost:5173` |

`RAILS_MAX_THREADS`, `PORT`, and `RAILS_LOG_LEVEL` are read from the environment too. They are not in `.env.example`.

Encrypted credentials live in `config/credentials.yml.enc`. They need `config/master.key`, which is gitignored, or `RAILS_MASTER_KEY`.

## Conventions

- API-only: no sessions, no cookies, no view layer. Authentication is not wired up yet.
- Collections return a `{ data, pagination }` envelope. CORS also exposes the `Link` and `X-Total-Count` headers, set alongside it.
- Active Job, Active Storage, Action Mailer, Action Mailbox, Action Text, and Action Cable are disabled in `config/application.rb`. Re-enable a framework there before using it.
- Ruby style is `rubocop-rails-omakase` with no overrides. It puts spaces inside brackets: `[ :get, :post ]`.

## Deployment

The `Dockerfile` builds the API for production only. `.dockerignore` excludes `web/`, so the SPA is built and hosted separately.

```sh
docker build -t sms .
docker run -d -p 80:3000 --name sms \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -e DATABASE_HOST=... -e DATABASE_PORT=5432 \
  -e DATABASE_USER=... -e DATABASE_PASSWORD=... \
  sms
```

The database variables are required. The entrypoint runs `db:prepare` before booting the server, and `config/database.yml` has no fallbacks. Without them the container exits immediately. It also needs a network route to Postgres. The Compose database is not reachable from a default-bridge container. Production ignores `DATABASE_NAME` and always uses `sms_production`.

Production forces SSL and logs to STDOUT.
