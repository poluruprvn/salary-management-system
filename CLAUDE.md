# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Salary management system. Rails 8.1 API-only backend, with a separate Vite/React SPA in `web/`. They are independent deploy artifacts. `.dockerignore` excludes `/web` from the Rails image.

## Commands

Backend (repo root):
- `bin/setup --skip-server`: install gems, prepare the DB. Plain `bin/setup` execs `bin/dev` and never returns.
- `bin/dev`: Rails server on port 3000.
- `docker compose up -d --wait postgres`: compose runs only the database.
- `bundle exec rspec`: test suite. Single file or example: `bundle exec rspec spec/models/foo_spec.rb:42`.
- `bin/ci`: re-runs `bin/setup --skip-server`, then rubocop, bundler-audit, brakeman. **It does not run rspec.** Run rspec separately before calling a change verified.
- `bin/rubocop`, `bin/rubocop -a`: lint, autocorrect.

Frontend (`web/`):
- `npm run dev` (port 5173), `npm run build` (`tsc -b && vite build`), `npm run lint` (oxlint).
- No test runner and no formatter are installed.

## Setup

`.env` is required and gitignored. Copy it with `cp .env.example .env`. `config/database.yml` has no defaults for `DATABASE_HOST/PORT/USER/PASSWORD`. `compose.yaml` fails without `DATABASE_USER`.

Gems install to `vendor/bundle`, set by the committed `.bundle/config`. Use `bundle exec` or the `bin/` binstubs. Building the `pg` gem needs `libpq-dev` and `build-essential` on the host, or the distro equivalent.

## Testing

`.rspec` requires only `spec_helper`. Every spec file must `require 'rails_helper'` itself, or Rails will not load. The test database is a separate database (`TEST_DATABASE_NAME`), not a schema. `factory_bot_rails` is available. There is no `spec/factories/` yet, and no specs have been written.

## Style

Ruby follows rubocop-rails-omakase with no overrides. It puts spaces inside brackets: `[ :get, :post ]`, `{ foo: 1 }`.

TypeScript: import through the `@/*` alias (→ `web/src/*`), not deep relative paths. `web/src/lib/utils.ts` re-exports `cn` from the `cn` package. Do not replace it with a hand-written clsx + tailwind-merge helper. `web/CLAUDE.md` has the rest, including the tsconfig flags and the Tailwind v4 setup.

Never write complex prose. In docs, comments, commit messages, and PR descriptions: short sentences, plain words, one idea each. No hedging, no filler, no rhetorical flourish. No em dashes; use a colon, a comma, or a full stop.

Comments stay short and to the point. Explain why, not what: a workaround, a spec quirk, a tradeoff. Do not restate the code, narrate a change (`# added this`), or add docstrings to a file that does not already use them.

Keep commit messages short. A one-line description of what changed is enough.

## Gotchas

- `config/application.rb` disables active_job, active_storage, action_mailer, action_mailbox, action_text, and action_cable. No background jobs, uploads, or mail until one is re-enabled there.
- API-only: no sessions, no cookies. Authentication is not wired up at all. There is no gem, no `current_user`, no authorization layer. Do not write code that assumes one.
- `config/initializers/cors.rb` allows `CORS_ORIGINS`, default `http://localhost:5173`. It exposes `Link` and `X-Total-Count`. Paginate with those headers, not a JSON envelope.
- No migrations or `db/schema.rb` exist yet. `db:prepare` creates an empty database.
