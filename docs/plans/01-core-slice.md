# Salary management: core API slice

## Context

`docs/requirements.md` is the spec. The repo is a bare Rails 8.1.3.1 API-only skeleton with no domain code.

This plan is the backend only: sign in, employees, and salary revision history. The SPA in `web/` is untouched here and gets its own numbered plan. Later plans also add one-time payments, the employer cost multiplier, analytics, the monthly register, and CSV import and export. Two things here must not need rewriting: the schema, and the salary-in-force query analytics will reuse.

## Decisions

- **Money is `bigint` cents.** One base currency, exposed through `GET /api/v1/meta`.
- **Every primary key is a UUIDv7**, defaulted in the database by Postgres 18's native `uuidv7()`. It is time ordered, so inserts stay at the right edge of every index and `id` doubles as a stable creation-order tiebreak. Rails' `id: :uuid` defaults to `gen_random_uuid()`, which is v4 and gives up both, so every table names the function itself.
- **The employee id is that primary key.** `employees.id` is the UUIDv7 and there is no separate `employee_number`. Two costs come with that. The spec's import section matches employees on employee number, so the importer has to match on `id` when the file carries one and on `email` when it does not. And a UUID is not something a person reads out over a phone, so the UI identifies an employee by name and email and keeps the id in the URL.
- **Status is derived, never stored.** Always as of a date, which defaults to today, with the response naming the date it used. Exit date is inclusive: the register pays that day.
- **Salary in force is a lateral join**, not a `current_salary_cents` column. A stored column cannot answer "as of a date", and moving `as_of` forward is how the spec previews approved raises.
- **Access is a JWT, refresh is a row.** Short lived HS256 access token, checked by signature and never looked up. The refresh token is opaque random stored as a SHA-256 digest, deleted on sign out. bcrypt guards the password only.
- **No access token blacklist.** Sign out ends a session within one access token lifetime, not instantly. A denylist would put a database read back on every request.
- **Pagination is a generic concern**, offset based, over a JSON envelope with `Link` and `X-Total-Count` kept alongside it. `Pagination#paginate` knows nothing about the resource and owns the slice: no scope calls `limit` or `offset`. Employees is the only caller today. Cursor pagination is out of scope: at 10,000 rows the deepest offset is a few hundred pages, and a cursor costs an opaque token per sort key and takes away jumping to a page.
- **No query layer, but a service layer.** Reads are scopes on the model, composed at the call site. Writes are one class per operation in `app/services/`, owning the transaction and raising on failure. An `app/queries/` object would hold what a scope holds anyway, while a write with rules in the controller has nowhere to go when the importer and the register need the same rules.
- **Serialization is plain POROs** in `app/serializers`.
- **Auditing is the `audited` gem**, not hand-rolled. It writes inside the save transaction, already skips empty changesets, and its railtie wires the actor sweeper into `ActionController::API`.
- **The API contract is generated, not written.** rswag turns the request specs into OpenAPI 3, served with Swagger UI at `/api-docs`. A hand-written document drifts from the API on day one.
- **Nothing is destroyed.** Revisions get `voided_at`, employees get `exit_date`. No `DELETE /employees/:id`.

### `voided_at` on `salary_revisions`

The deferred register freeze detects records changed after a register was issued. `created_at` and `updated_at` cover insert and update; neither covers a delete, so a backdated correction would silently never appear as an adjustment.

So `salary_revisions` gets `voided_at` and a **partial** unique index on `(employee_id, effective_date) WHERE voided_at IS NULL`, and `DELETE .../salary_revisions/:id` sets it. This belongs in the first migration: converting a plain unique index to a partial one later means re-auditing every query that assumed hard deletes. `upsert_all` appends a partial index's `WHERE` to the conflict target, so the deferred CSV upsert still works.

No `default_scope`: the query that matters is hand-written SQL it would not reach. Use `scope :live` plus a spec asserting a voided revision is invisible to the lateral.

---

## Phase 0: Make the harness honest

Nothing downstream is verifiable until this is done.

- **`spec/spec_helper.rb`**: the config block sits inside `=begin`/`=end` and is inert. Revive it. It also turns on `disable_monkey_patching!`, so every group is `RSpec.describe`, and `spec/examples.txt`, which needs a `.gitignore` line.
- **`spec/rails_helper.rb`**: uncomment `infer_spec_type_from_file_location!` and the `spec/support/**/*.rb` glob, include `FactoryBot::Syntax::Methods`, configure shoulda-matchers. The first is load bearing: rspec-rails only mixes `CurrentAttributes::TestHelper` into groups carrying `type:` metadata, so without it `ActiveSupport::CurrentAttributes` is never reset and state leaks between examples.
- **`config/environments/test.rb`**: `ActiveModel::SecurePassword.min_cost = true`, or every `create(:user)` costs about 80 ms.
- **`Gemfile`**: `audited`, `bcrypt` and `jwt` ungrouped, `rswag-api` and `rswag-ui` (development), `faker` (development, test), `rswag-specs` and `shoulda-matchers` (test). Then `bundle install`, not `bundle update`. `audited` 5.8.0 allows `activerecord < 8.2`, so it installs on 8.1. `rswag-api` and `rswag-ui` are engines whose generators write `mount Rswag::Ui::Engine` into `config/routes.rb` and a `config/initializers/rswag_ui.rb`. Both files load in every environment, so both need a `defined?(Rswag::Ui::Engine)` guard. Without it production boots into `NameError: uninitialized constant Rswag`.
- **`config/ci.rb`**: add `step "Tests: Ruby", "bundle exec rspec"`, add `step "Docs: OpenAPI up to date", "RAILS_ENV=test bin/rails rswag && git diff --exit-code swagger/"`, and change setup to `SEED_EMPLOYEE_COUNT=50 bin/setup --skip-server`. `db:prepare` seeds whenever it creates a database, so on a fresh checkout `bin/ci` would seed 10,000 employees before linting. `RAILS_ENV=test` is load bearing: `rswag-specs` is a test group gem, and its railtie is what defines the `rswag` task, so in development rake cannot find the task at all. `step` hands a single string to `system`, so the env prefix and the `&&` both go through a shell. Then fix the "does not run rspec" line in `CLAUDE.md` and `README.md`.

**Verify:** `bundle exec rspec` runs zero examples and exits 0.

---

## Phase 1: Schema

One migration per table.

Every one of them takes `id: :uuid, default: -> { "uuidv7()" }`, and every reference takes `type: :uuid`.

| Table | Columns and constraints |
| --- | --- |
| `users` | `email` unique, `password_digest`, `name` |
| `refresh_tokens` | `user_id` fk, `token_digest` unique, `expires_at` (indexed), `last_used_at` |
| `countries` | `string code limit: 2` unique + check, `name`, `employer_cost_multiplier` decimal(6,4) default 1.0 check `> 0` |
| `departments` | `name` unique |
| `levels` | `code` unique, `name`, `rank` integer **not null** unique |
| `employees` | `name` not null, `email` unique, `country_id`/`department_id`/`level_id` fks not null, `title` not null, `hire_date` not null, `exit_date` nullable, check `exit_date IS NULL OR exit_date >= hire_date`, `t.timestamps` |
| `salary_revisions` | `employee_id` fk, `amount_cents` bigint check `> 0`, `effective_date`, `reason` + check over the four values, `note` text, `voided_at`, `t.timestamps` (both not null), **partial unique index on `(employee_id, effective_date) WHERE voided_at IS NULL`**, index on `updated_at` |

Load bearing details:

- `uuidv7()` is a Postgres 18 builtin. `compose.yaml` pins `postgres:18-alpine`, so it is there. On an older server the function does not exist and every insert fails, which is a loud failure on the first migration rather than a quiet one later.
- There is no access token table. That is the point of the JWT. `refresh_tokens` is the only auth row, and it is what sign out deletes.
- The partial unique index is the CSV upsert key, the index the lateral scans backwards, and the guard against two live revisions on one day. The deferred freeze detects work done after a register was issued, and a voided or corrected revision moves only `updated_at`, so `updated_at` is the indexed column. `updated_at >= created_at` always holds, so one index answers inserts and edits both. `employees` needs the same index for a backdated hire or exit.
- The `audits` table comes from `rails g audited:install`, but the generated migration **must be edited before it runs**. Its template hardcodes `auditable_id` and `associated_id` as `:integer`, and only `user_id` is configurable. An integer column given a UUID does not raise: Rails casts the string through `to_i`, so `01a0d24e-...` becomes `1` and every audit row silently points at whatever record holds that id. Generate with `--audited-user-id-column-type=uuid --audited-changes-column-type=jsonb`, then change the two polymorphic id columns to `:uuid` and the table to `id: :uuid, default: -> { "uuidv7()" }` by hand. `jsonb` over the default `text` is worth taking here because the trail is read back through an endpoint, not just written.
- The `auditable` and `user` associations are polymorphic, so there are no foreign keys and no cascade can erase the trail, which is what this table needs anyway. The generator already indexes `(associated_type, associated_id)` for reading one employee's history.
- `countries.code` is `string limit: 2`, not `char(2)`: `bpchar` is blank padded and its comparison semantics surprise people.
- Emails are downcased before validation, so a plain unique index catches a duplicate that differs only in case. The deferred importer resolves a spreadsheet's `engineering` to the `Engineering` row with a `lower()` comparison over nine rows. Neither stops "Eng" versus "Engineering"; only the closed set does.
- `employees.email` is unique on purpose. A duplicate email in an HR system is a data error worth surfacing, and the deferred importer must report it as "email already used by Ada Lovelace", not as a raw constraint violation. With `employee_number` gone, email is also the only human-typed key an imported spreadsheet can match on.
- Indexes: btree on the three fks plus `hire_date`, `exit_date` and `updated_at`; btree on `(lower(name), id)` for the default sort, per Phase 2; btree on `title` for equality filtering.
- **Search has no index.** `q` is `ILIKE '%term%'` over `name`, `email` and `title`, which a btree cannot serve because a leading wildcard leaves no prefix to seek on, so it is a sequential scan. At 10,000 rows that is single digit milliseconds against a 300 ms budget. It is linear in row count, so it is the first thing to revisit at roughly ten times this size.
- **`id` is not one of the searched columns.** `ILIKE` has no operator for `uuid`, so matching it means casting every row to text. A `q` that parses as a UUID is instead an equality match on `id`, and one that does not skips the column. Nobody types a substring of a UUID.

**Verify:** `bin/rails db:migrate`, then `bin/rails db:test:prepare`. Read `db/schema.rb` and confirm the check constraints and the partial unique index survived the dump, and that every `id` reads `default: -> { "uuidv7()" }` rather than `gen_random_uuid()`.

---

## Phase 2: Models

`app/models/{user,refresh_token,country,department,level,employee,salary_revision}.rb`, plus `spec/factories/` and `spec/models/`.

- `User`: `has_secure_password reset_token: false`. Rails 8.1 defaults that to `true`, and password reset is out of scope. `before_validation` downcases the email.
- `RefreshToken`: `.issue!(user)` returns the raw `SecureRandom.urlsafe_base64(32)` once and stores only `Digest::SHA256.hexdigest`. `scope :active`. `.claim!(raw)` finds the live row, deletes it and issues a replacement, so every refresh rotates. Expired rows are swept during refresh; there are no background jobs.
- `Employee`: `status_as_of(date)`, scopes `active_as_of` / `pending_as_of` / `exited_as_of`, `salary_as_of(date)` for the single-record path. Validates uniqueness of `email`, presence of every not-null column, and downcases the email before validation.
- `SalaryRevision`: `scope :live`, validates `effective_date` within the hire and exit dates, `reason` inclusion, `amount_cents > 0`, and uniqueness of `effective_date` scoped to `employee_id` across live rows. Moving an employee's `exit_date` earlier does not revalidate revisions already on file, so one can end up dated after the exit. It is inert: the register pays active days only, and the lateral is read through a status the same date derives. The alternative is a cascade nobody asked for.

No model mints its own `id`. The column default is the only place a UUID comes from, and `id` is never in a permitted params list.

Each uniqueness validation is a read followed by a write, so the index is what actually holds the line. The validation buys a 422 naming a field; Phase 4 catches what falls between them.

Sort names on `lower(name)`, not `name`. This database collates by code point, so `ORDER BY name` puts every capital before every lowercase: `Bob, Zoe, adam, alice`. That is page 1 of the default sort on the first screen anyone opens. The `(lower(name), id)` index serves the fixed version with a plain index scan. Accented names still sort after `z`, accepted for English data.

**Verify:** `bundle exec rspec spec/models` green, including the exit-date check constraint and the partial unique index.

---

## Phase 3: Auditing

`audited` covers the requirement, so this phase is configuration rather than code.

- `audited` on `Employee`, and `audited associated_with: :employee` on `SalaryRevision`, so one employee's trail includes their raises.
- The gem's callbacks run inside the save transaction, so a change and its trail commit or roll back together. That is the spec's requirement, met by default.
- A no-op `PATCH` writes nothing: `auditor.rb` guards the write with `unless audited_changes.empty?`. No bail-out to hand-write.
- The actor comes from `Audited::Sweeper`, which the railtie registers as an `around_action` on `ActionController::API` and which calls `current_user` on the controller. It also records `remote_address` and `request_uuid`.
- Factories have no controller and therefore no actor, which is correct: `user` is simply nil on those rows. Nothing needs disabling globally in specs, and a spec that wants a real actor wraps the write in `Audited::Audit.as_user(user)`.

The one thing the gem does not do is expose a callable write path. Its callbacks are bypassed by `upsert_all`, so the deferred CSV importer will have to write its own rows. That is a problem for the plan that adds the importer, not this one.

**Verify:** a spec proving the audit row rolls back with a failed save, and one proving a no-op update writes nothing. Also assert `auditable_id` round trips as a UUID, which is what catches the integer column described in Phase 1. The actor assertion needs a controller, so it belongs to Phase 6, not here.

## Phase 4: Auth and the error contract

`app/controllers/concerns/{authentication,error_handling,pagination}.rb`, `app/services/access_token.rb`, `app/services/auth/{sign_in,refresh,sign_out}.rb`, `app/controllers/api/v1/base_controller.rb`, `sessions_controller.rb`, `config/routes.rb`.

Define the error shape before the first controller, or 200 spec assertions get rewritten later:

```json
{ "error": { "code": "validation_failed", "message": "...", "details": [ { "field": "email", "message": "is invalid" } ] } }
```

`rescue_from` covers `RecordNotFound` (404), `RecordInvalid` (422), `ParameterMissing` (400), `RecordNotUnique` (422), `Employee::UnknownSortKey` (422) from Phase 5, and `Auth::InvalidCredentials` (401). `RecordNotUnique` is not padding: a second raise on an occupied date or a duplicate email is an ordinary action where the Phase 2 validation loses the race to the index, and without the handler the loser is a 500. It maps to 422 rather than 409 so the client has one path, with empty `details` because the adapter error names a constraint, not a field.

A malformed UUID needs no handler. Rails casts an unparseable value for a `uuid` column to `nil`, so `Employee.find("nonsense")` queries `id = NULL`, matches nothing and raises `RecordNotFound`, which is already a 404. The same cast turns `department_id[]=nonsense` into an empty page rather than an error. Phase 8 asserts both instead of coding around them.

`app/controllers/concerns/pagination.rb` is resource agnostic. `paginate(relation, total: nil)` returns the page slice and the metadata, and every collection endpoint renders one envelope:

```json
{
  "data": [ ... ],
  "pagination": { "total": 10000, "page": 3, "per_page": 25, "total_pages": 400, "prev_page": 2, "next_page": 4 }
}
```

The envelope is canonical. `prev_page` and `next_page` are null at the ends, so a consumer never computes a page number that does not exist.

- **The body carries it because not every consumer is a browser.** Headers are awkward for anything that speaks JSON: an MCP tool returns a JSON result, so header-based paging means every wrapper re-plumbs `X-Total-Count` into the payload by hand. Scripts and `curl` have the same problem. One shape in the body works everywhere.
- `Link` and `X-Total-Count` are still set, because `config/initializers/cors.rb` already exposes exactly those two and they are standard HTTP. They are a convenience, not the contract, so no new header is invented and the CORS config does not change. A custom header that CORS does not expose is invisible to `fetch` with no error at all, which is a failure mode worth not buying.
- `page` and `per_page` come from params, default to 1 and 25, and cap at 100. Above the cap clamps, because a limit is not an error. Zero, negative or unparseable is a 422. `per_page` in the envelope reports what was used, so a client that asked for 1000 can see it got 100.
- `total:` is for callers with a cheaper count than `relation.count`, which employees has: `#count_relation` drops the lateral. It defaults to `relation.count`, so a plain resource calls `paginate(Country.all)` and is done.
- `Link` is built by rewriting the `page` param on `request.url`, so every filter, `sort` and `as_of` survives into the links and no resource knowledge leaks into the concern.
- A page past the end is an empty `data` with correct metadata, not a 404.
- `paginate` is the only place `limit` and `offset` are applied. Phase 5's scopes hand it an unsliced relation and never page themselves.

`sessions_controller.rb` holds no auth logic. Each action calls `Auth::SignIn`, `Auth::Refresh` or `Auth::SignOut`, following Phase 5's service rules. `AccessToken` is not one of those: it is a value object that encodes and decodes, and the services call it.

`app/services/access_token.rb` is the only place a JWT is minted or read. `.encode(user)` signs `sub`, `iat`, `exp` and `jti` with HS256 over `Rails.application.secret_key_base`, so there is no new environment variable. The `jti` is for log correlation, not revocation.

- **Pin the algorithm and leave verification on.** `JWT.decode(token, key, false)` skips the signature, and trusting the token's own `alg` header accepts `alg: none`. Pass `algorithm: "HS256"`.
- **An expired access token is 401 with `code: "token_expired"`**, distinct from `invalid_token`, so the client can choose between refreshing and giving up.

Access tokens live 15 minutes, refresh tokens 30 days. Sign out deletes every refresh row for the user and does nothing to an access token in flight, which keeps verifying until `exp`. That window is the accepted cost of having no blacklist; shorten the access lifetime if it matters.

`config/initializers/filter_parameter_logging.rb` gains `:amount_cents` and `:salary`. It already carries `:passw` and `:email`, and matching is partial.

`as_of` defaults to today, which is what the spec requires, and every response that used it echoes the date back. `config.time_zone` is UTC, so an unqualified "today" rolls over at 05:30 for a manager in IST. Echoing the resolved date is what makes that visible and a shared link reproducible: the client reads `as_of` off the first response and pins it into the ones that follow. An `as_of` that does not parse is a 422, never a silent fall back to today.

**Verify:** sign in returning both tokens, an authenticated request, refresh rotating the row, sign out deleting it, a refresh after sign out failing, an expired access token, a tampered payload, a malformed header, a missing header.

---

## Phase 5: Scopes and services

There is no `app/queries/`. Reads are scopes on the Phase 2 models, writes are services in `app/services/`, and Phase 6's controllers permit params, call one of the two, and serialize what comes back. A scope returns a relation and never executes. A service owns a transaction and returns a record.

### Reads

Three scopes on `Employee`, added to the file Phase 2 created.

`filtered(filters)` handles `q`, `department_id[]`, `country_id[]`, `level_id[]`, `title` and `status`. Filters only: no lateral, no order. `q` matches `name`, `email` and `title` with `ILIKE`. A `q` that parses as a UUID is an equality match on `id` instead, per Phase 1.

`with_salary_as_of(date)` adds the lateral. `sorted_by(key)` adds the order and whatever join the key needs.

The controller composes them:

```ruby
base = Employee.filtered(filter_params)
paginate(base.with_salary_as_of(as_of).sorted_by(sort_param), total: base.count)
```

That composition is the argument against a query object here. `COUNT` runs on the filter relation and never pays for the salary lookup. A `#count_relation` and a `#page_relation` say the same thing, but the call site shows neither, so the two can drift apart and nothing looks wrong. Here they are one variable.

`page` and `per_page` appear nowhere in this phase. Phase 4's `paginate` owns the limit and the offset.

The analytics phase adds a salary *filter*. It belongs in `filtered`, and the count then pays for the lateral, which is correct: a count that skips a filter disagrees with the page. `joins!` unions its arguments, so `with_salary_as_of` chained onto a `filtered` that already joined on the same date is one join. Two different dates would be two joins and an ambiguous column, so `as_of` is resolved once per request and passed to both.

```sql
LEFT JOIN LATERAL (
  SELECT amount_cents, effective_date, reason
  FROM salary_revisions sr
  WHERE sr.employee_id = employees.id
    AND sr.effective_date <= :as_of
    AND sr.voided_at IS NULL
  ORDER BY sr.effective_date DESC
  LIMIT 1
) current_salary ON TRUE
```

**Do not add `, sr.id DESC` as a tiebreak.** The partial unique index already guarantees at most one live row per date, so the tiebreak is logically dead, but the planner cannot prove it: it fails pathkey containment and inserts an Incremental Sort started once per outer row. Without it the plan is a plain backward index scan. Sorting 10,000 employees by salary is the query that exposes this.

Build the fragment with `sanitize_sql_array` and bind `as_of`. `bin/ci` runs `brakeman --exit-on-warn`, so one injection warning fails the build. If Brakeman still flags the sanitized heredoc, record it in `config/brakeman.ignore` rather than weakening the query.

Sorting is in the spec: server side search, filter, sort and pagination, because 10,000 rows do not belong in browser memory. The keys are `name`, `hire_date`, `exit_date`, `salary`, `department`, `country` and `level`, with `-` for descending. They live in a frozen hash, and `sorted_by` raises `Employee::UnknownSortKey` on anything else. Phase 4 rescues it as a 422. An unknown key is never a silent fallback to the default sort.

- `name` maps to `lower(employees.name)`.
- `level` maps to `levels.rank`, never to `code` or `name`. As text `L10` sorts before `L2`, and `rank` is not null in Phase 1 exactly so this sort has something to mean.
- `department` and `country` map to their `name`. All three reference fks are not null, so `sorted_by` adds these as inner joins and no employee can fall out of the page.
- There is no sort by id. A v7 id orders by creation time, which `hire_date` already says better, and an opaque key is not a thing anyone asks a list to sort by.
- **Every sort ends `, employees.id ASC`**, or offset pagination over duplicate names splits pages nondeterministically and drops rows. v7 makes that tiebreak creation order rather than noise.
- **`salary` and `exit_date` sort `NULLS LAST` in both directions**: the lateral is a `LEFT JOIN`, so an employee with no live revision as of `as_of` has a null amount, and Postgres puts nulls first on `DESC`, opening "highest paid" on a block of blanks. `exit_date` is null for everyone still employed, which is most of the table.

`SalaryRevision.history_for(employee)` returns one employee's history newest first, with the previous amount from a window function rather than an N+1:

```sql
SELECT id, amount_cents, effective_date, reason, note,
       LAG(amount_cents) OVER (PARTITION BY employee_id ORDER BY effective_date, id) AS previous_amount_cents
FROM salary_revisions
WHERE employee_id = $1 AND voided_at IS NULL
ORDER BY effective_date DESC, id DESC
```

The delta is computed from this, never stored. The `, id` in the window is defensive only: the partial unique index already allows one live row per date, so the tie never happens.

### Writes

One class per operation under `app/services/`, `.call` as the entry point, the transaction inside: `Employees::Create`, `Employees::Update`, `SalaryRevisions::Create`, `SalaryRevisions::Update`, `SalaryRevisions::Void`, plus the `Auth::` three Phase 4 already builds.

- **A service raises, it does not return a result object.** `create!` and `update!`, plus `Auth::InvalidCredentials` for a bad password. Phase 4's `rescue_from` already maps `RecordInvalid` to 422 and an auth failure to 401, so an action is one call and one render. A `Result` wrapper means every action re-branches on what the error contract already handles in one place.
- **A service never sees `params`, never renders, and never names a status code.** The controller permits and hands over a hash.
- **A service returns the record**, or a `Data.define` value when the caller needs more than the record.
- Auditing is unaffected. `Audited::Sweeper` is an `around_action`, so the actor is set before the action calls the service and rows written inside still carry the user.

`SalaryRevisions::Create` is the one carrying weight today. It reads the live revision preceding the new effective date, inserts, and returns both, which is what Phase 6's response promises. `SalaryRevisions::Void` sets `voided_at` instead of deleting, per Phase 1, and is an ordinary audited update. `Auth::Refresh` mints the access token and calls `RefreshToken.claim!`; the digest and the row rotation stay on the model, because they are about the row and not about the operation.

`Employees::Update` is `employee.update!(attrs)` and nothing else, and `Employees::Create` is barely more. That is accepted. The layer earns its place by being the one answer to where a write lives, and that collapses the moment one resource writes through a service and another writes through the model in a controller. It also gives the deferred work a home that already exists: the importer's all-or-nothing validation, the register issue and freeze, and the adjustment lines are all write orchestration over more than one table, and none of them belong in a model.

**Verify:** `spec/models/` covering the scopes, the status boundaries especially `as_of == exit_date` being active, and an unknown sort key raising. `spec/services/` covering each write, `SalaryRevisions::Create` with no prior revision and with one, and a failed write leaving no rows. Then `EXPLAIN ANALYZE` the lateral against seeded data and confirm there is no Incremental Sort node.

---

## Phase 6: API

Routes under `namespace :api, :v1`, `defaults: { format: :json }`:

```
POST   /api/v1/auth/sign_in                                  # returns access_token, expires_in, refresh_token
POST   /api/v1/auth/refresh                                  # rotates: new pair, old refresh row deleted
DELETE /api/v1/auth/sign_out                                 # deletes every refresh row for the user
GET    /api/v1/me
GET    /api/v1/meta                                          # base currency, minor unit, enums, today
GET    /api/v1/employees                                     # search, filter, sort, paginate, as_of
POST   /api/v1/employees
GET    /api/v1/employees/:id                                 # as_of applies here too
PATCH  /api/v1/employees/:id
GET    /api/v1/employees/:employee_id/salary_revisions
POST   /api/v1/employees/:employee_id/salary_revisions
PATCH  /api/v1/employees/:employee_id/salary_revisions/:id
DELETE /api/v1/employees/:employee_id/salary_revisions/:id   # voids
GET    /api/v1/employees/:employee_id/audits                 # who changed what, when
GET    /api/v1/countries | /departments | /levels            # closed sets, unpaginated
GET    /api/v1/titles?q=

GET    /healthz                                              # process + database, 503 if either is down
GET    /readyz                                               # the same, plus no pending migrations
```

Every `:id` is a UUID. Controllers stay thin by construction: permit params, call a Phase 5 scope or service, render a serializer. No action opens a transaction or writes SQL.

Collections return `{ data, pagination }`. Single resources return a bare object. The employee payload carries `status` and the `as_of` that produced it, the three reference objects, and `current_salary` as `{ amount_cents, effective_date }`.

`GET /meta` reads the currency as `ENV.fetch("BASE_CURRENCY", "USD")`. `.env` is gitignored, so an existing checkout will not have the key and a bare fetch would fail the first request after a pull. It also returns the server's today, which is the `as_of` a caller gets by omitting the parameter.

**`POST .../salary_revisions` returns the created revision with `previous_amount_cents` and `previous_effective_date`**, which `SalaryRevisions::Create` hands back alongside the record, so the form renders "120,000 to 132,000, up 10%" without a second round trip. A *backdated* revision also changes the previous value of the one after it, so the client invalidates the whole history query rather than patching a row.

**`GET .../audits`** is the only way the trail is readable. Phase 3 writes it, the spec asks for a record of who changed what and when, and a record nobody can read is not one. It returns `employee.own_and_associated_audits`, which the gem already orders newest first and which covers the employee's own changes and their revisions, through the same pagination concern. Each row carries the action, `audited_changes`, the actor and the time.

**`GET /titles`** returns distinct titles with a usage count, matched anywhere in the string, ordered by count descending and capped at 20 rows. The spec expects hundreds of distinct titles and this feeds a typeahead, not a report, so it does not paginate: it truncates. The count is what converges the set: the manager picks "Senior Engineer (142)" over "Sr. Engineer (1)". It matches all employees ever, not the `as_of` set. No index serves `SELECT DISTINCT`, so this is a sequential scan like the employee search.

**The contract is OpenAPI 3, generated by rswag from the request specs**, not a hand-written `docs/api.md`. `spec/swagger_helper.rb` sets `openapi_root`, one `openapi_specs` entry for `v1/openapi.yaml`, `openapi_format = :yaml`, and `openapi_strict_schema_validation = true` so a response that does not match its declared schema fails the example rather than quietly documenting a lie.

`RAILS_ENV=test bin/rails rswag` regenerates `swagger/v1/openapi.yaml`, which is committed. `rswag-api` serves it and `rswag-ui` mounts Swagger UI at `/api-docs`. Both ship their own `Rack::Static` middleware instead of relying on `ActionDispatch::Static`, so `config.api_only = true` does not break them. They sit in the `development` group, because Swagger UI does not belong in front of production salary data. That is why the mount in `config/routes.rb` and `config/initializers/rswag_ui.rb` both need a `defined?` guard: those files load in production too, where the constant is not there.

Two things to expect. The rake task runs rspec with `--order defined`, overriding the random order Phase 0 turns on, so generation and the normal suite deliberately run in different orders. And rswag's DSL is a poor fit for a few of the Phase 8 cases, notably asserting a 422 with validations skipped: write the documented paths in the DSL and leave the awkward ones as plain request specs beside them. Both kinds live in `spec/requests/`.

Then update `web/CLAUDE.md`, which says no API contract exists, to point at `/api-docs`.

**Both health endpoints check Postgres.** That means dropping `rails/health#show`, which the generator routed at `/up`: it reports only that the process booted, and it is a fixed controller with no hook for a dependency check. Replace it with one `HealthController`, and delete the generated `/up` route. `config/environments/production.rb` sets `silence_healthcheck_path = "/up"`, so move it to `/healthz` in the same change or every probe writes a request log line. The `/up` excludes in the `ssl_options` and `host_authorization` lines above it are commented out, so they are a trap only for whoever uncomments them.

- `/healthz`: `ActiveRecord::Base.connection_pool.with_connection { |c| c.select_value("SELECT 1") }`. 200 with `{ "status": "ok", "database": "ok" }`, or 503 naming what failed.
- `/readyz`: the same check plus no pending migrations. Note that the container cannot hit that case, because `bin/docker-entrypoint` runs `db:prepare` and then execs the server, so the two endpoints agree there. It catches development, where `bin/dev` runs no migrations and a branch with a new one leaves the app serving against an old schema.

Both stay outside `namespace :api, :v1` and outside `Api::V1::BaseController`, so the authentication `before_action` never reaches them. A load balancer has no bearer token.

One consequence to know. Liveness now fails whenever Postgres does, and under an orchestrator that restarts on a failed liveness probe that turns a brief database outage into a restart of every instance at once. This deploys as a single container with no such probe, so it does not bite here. If that changes, point the liveness probe at a process-only endpoint rather than loosening these two.

`/employees` and `/audits` paginate today. The concern exists so the deferred list endpoints do not each reinvent the envelope.

**Verify:** `spec/requests/api/v1/` green, asserting the `pagination` envelope on the first, middle and last page, and `user` populated on an audit written through a signed-in request. That last one is Phase 3's assertion, deferred to here because it needs a controller to have an actor at all.

---

## Phase 7: Seeds

`db/seeds.rb`, deterministic via a fixed `Random` seed, idempotent via `insert_all` with `unique_by`, wrapped in `Audited.auditing_enabled = false`. Deterministic covers the field values, not the ids: a UUID comes from the database and differs between machines, so nothing may key on a seeded id.

**First line: `return` unless the environment is development or test.** `bin/docker-entrypoint` runs `db:prepare` before the server, and that seeds whenever it creates a database. So the first production boot against an empty database runs this file and dies on `NameError`, because Faker is not in the production bundle. Bundling Faker would be worse: 10,000 invented employees in production.

It has to be `return`, not `abort`. `abort` raises `SystemExit`, `db:prepare` fails with it, and `bin/docker-entrypoint` runs under `bash -e`, so the container never reaches `exec` and the first deploy fails. The second boot would succeed, because `prepare_all` seeds only when it creates the database, but a deploy that has to fail once is not worth shipping. Top-level `return` in a `load`ed file is valid Ruby and simply skips the rest.

- One HR user from `SEED_HR_EMAIL` / `SEED_HR_PASSWORD` via `find_or_create_by!`, so `has_secure_password` hashes it. Read both with a default, not a bare `ENV.fetch`: `.env` is gitignored, so an existing checkout will not have the new keys and `bin/ci` now runs the seeds.
- About 9 countries with real multipliers, 9 departments, 7 levels.
- `ENV.fetch("SEED_EMPLOYEE_COUNT", 10_000)` employees in batches of 2,000, with explicit timestamps because `insert_all` skips them.
- Roughly 35,000 salary revisions: one at hire plus zero to four raises at 12 to 18 month intervals, scaled by level and country.
- About 8% carry an exit date, 1% a future hire date so `pending` is demonstrable, 3% a future-dated raise so moving `as_of` visibly changes the answer.

Employees upsert on `email`, which is the only unique human-typed column left now that `employee_number` is gone. Revisions upsert on the partial index, which Rails handles: `InsertAll#conflict_target` appends a partial index's `WHERE` to the conflict target.

One trap, replacing the `bigserial` one that UUIDs remove. Build the employee id map from a single `Employee.pluck(:email, :id)` after the insert, never from `returning:`. `unique_by` makes the insert `ON CONFLICT DO NOTHING`, so `returning:` yields only the rows that were actually written. On the second run that is none, the map comes back empty, and every salary revision then fails its foreign key.

`.env.example` gains `SEED_HR_EMAIL`, `SEED_HR_PASSWORD`, `SEED_EMPLOYEE_COUNT`, `BASE_CURRENCY=USD`.

**Verify:** run `bin/rails db:seed` twice and assert identical row counts, salary revisions included, which is the assertion that catches an empty id map. The seed spec covers the guard by stubbing `Rails.env` and asserting the file writes nothing.

---

## Phase 8: Specs

- **Models**: validations, database constraints, status at every boundary (day before hire, hire date, exit date, day after exit).
- **Scopes**: each filter alone and combined, both directions on every sort key, search across `name`, `email` and `title`, pagination boundaries including the last partial page. Plus `sort=name` putting `adam` before `Bob`, `sort=level` putting `L2` before `L10`, and `sort=-salary` putting an employee with no live revision last.
- **Salary in force**: no revisions, all revisions future, `as_of` exactly on an effective date, a future-dated raise ignored, a voided revision invisible.
- **Requests**: every endpoint in rswag's `path` / `response` / `run_test!` DSL, requiring `swagger_helper` rather than `rails_helper`, with 401, 404 and 422 in the documented shape, a bad `as_of`, an omitted `as_of` defaulting to today and being echoed in the response, `per_page` above the cap clamping and a bad `per_page` giving 422, an unknown sort key, a page past the end returning empty `data`, a malformed UUID giving 404 in the path and an empty page in a filter, `GET /titles` capped at 20, and `Link` carrying the active filters. Assert the `pagination` object on the first, middle and last page, including null `prev_page` and `next_page` at the ends and `per_page` reporting the clamped value. A duplicate email and a second revision on an occupied date each return 422 twice over: through the validation, and with validations skipped so the index raises.
- **Services**: each write on its own, `SalaryRevisions::Create` with no prior revision, with one, and backdated between two, a failed write leaving no rows, and `Auth::SignIn` raising `Auth::InvalidCredentials` on a wrong password.
- **Auditing**: same-transaction write, rollback writes none, no-op update writes none, `audited_changes` content, and `user` populated from the request.
- **Auth**: sign in success and failure, an expired token giving `token_expired` not `invalid_token`, a tampered payload, a wrong signing key, `alg: none`, refresh rotating the row, a replayed refresh token failing, sign out deleting the row. Assert the accepted window too: a token minted before sign out works until `exp`.
- **Seeds**: idempotence at `SEED_EMPLOYEE_COUNT=50`, including intra-batch duplicates, and the guard skipping the file outside development and test.

## Verification

From a clean state:

```sh
docker compose up -d --wait postgres
bin/setup --skip-server
bin/rails db:seed
bundle exec rspec
bin/ci
bin/dev                                 # :3000
```

Then drive it from Swagger UI at `http://localhost:3000/api-docs`: sign in with the seeded credentials, list employees, search by name, filter by department and level, sort by salary, add a raise with a future effective date, confirm the response carries the previous amount, then move `as_of` past that date and confirm the current salary changes and the active headcount moves with it. Sorting by salary descending must return the highest paid first, not the rows with no revision.

Must pass: `bundle exec rspec` green, `bin/ci` green.

## Notes for later plans

- `csv` is a bundled gem on Ruby 3.4 and is not in the Gemfile. Add it when import or export lands.
- The spec matches imported employees on employee number, which no longer exists. The importer matches on `id` when the file carries one, which is the round trip from an export, and on `email` when it does not, which is the first load out of Excel. `docs/requirements.md` needs that sentence changed when the importer lands.
- Issued register lines must snapshot `country_id` as it was at issue, because the CSV splits per country and country can change.
- The distribution and outlier answers share one query: compute p25/p50/p75 per cohort once with `percentile_cont`, then join back. Cohorts under five people need an explicit "not evaluated" state with a reason string, not an omission.
- Structure the lateral-joined relation so analytics compose on it with `GROUPING SETS`, rather than each answer re-deriving the join.
- The SPA plan needs `web/tsconfig.app.json` set to `"strict": true` before any component exists, and `--chart-1` through `--chart-5` in `web/src/index.css` are five greys, unusable as a categorical series.
