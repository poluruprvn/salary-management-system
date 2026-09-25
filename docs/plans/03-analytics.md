# Salary management: analytics

## Context

`docs/requirements.md` is the spec. `01-core-slice.md` built the API for employees and salary revisions. `02-core-slice-spa.md` built their screens. Countries already carry `employer_cost_multiplier`, but nothing reads it and nothing can edit it.

This plan answers the spec's questions about how the org pays people, in the API and in the SPA. It covers four of the five answers: run rate, distribution, outliers, and twelve months of headcount and pay movement. It also makes the multiplier editable, because a fully loaded number nobody can correct is not worth showing.

**Spend for a period is not here.** It is salary accrued plus one-time payments, and neither half exists yet. There is no payments table, and accrual is the register's pro rata: segments per revision, hire and exit, each rounded once. Building accrual here means building it twice. It moves to the plan that adds one-time payments, which is also where the register's pro rata lands.

## Decisions

- **Every answer is a read over the salary lateral.** `Employee::SALARY_AS_OF_JOIN` is the one definition of salary in force, and analytics composes on it rather than restating it. A second copy of that SQL drifts, and the day it drifts the dashboard disagrees with the list.
- **Reads stay scopes.** There is still no `app/queries/`. The analytics scopes live in `app/models/employee/analytics.rb`, a concern included in `Employee`, so `employee.rb` does not double in size. Each returns a relation. Controllers render it.
- **The population is active employees with a salary in force on `as_of`.** Run rate, distribution and outliers all use it. Headcount counts every active employee, and each answer also reports how many of them have no salary on file. That is how headcount and run rate agree: the gap is shown, not hidden.
- **Fully loaded rounds per employee.** `ROUND(amount_cents * employer_cost_multiplier)` per row, then `SUM`. `ROUND` on `numeric` is half away from zero, which on a positive amount is half up. A group total is the sum of its rows and the grand total is the sum of the groups, the same rule as the register.
- **Gross and loaded come back together.** Each answer returns both, and the UI switches between them. A `basis` param would double the requests for a toggle and save one multiply per row.
- **Fully loaded says it is at current rates.** The multiplier is not effective dated, so a past `as_of` shows past salaries at today's multipliers. The UI labels every loaded figure that way. The API does not carry a flag for it: it is always true.
- **Percentiles are `percentile_cont`, then rounded to the cent.** `percentile_cont` takes `double precision` only. Amounts under 2^53 cents convert exactly, so the only float step is the interpolation, and the result is rounded once, half up, through `numeric`. A percentile is a statistic, not money that has to foot, so this is the one place a float is accepted.
- **Grouping is a closed set of keys**, in a frozen hash like `SORT_KEYS`: `department`, `country`, `level`, and `title` for distribution only. An unknown key is an `InvalidParameter`, which is a 422.
- **One query per answer, totals included.** Run rate groups with `GROUPING SETS ((key), ())`, so the rows and the total come from one scan and cannot disagree. `group` takes the raw string, so no Arel.
- **Outliers share the distribution's percentiles.** One `cohort_stats` CTE computes p25, p50 and p75 per level and country. Distribution reads it grouped, outliers join back to it. Rails' `.with` builds the CTE.
- **The cohort is computed before any filter.** A department filter on outliers narrows who is listed, not who the fence is computed from. Filtering first would move the fence with the view, and the same person would be an outlier in one screen and not another.
- **Reports are not collections.** Analytics responses are `{ as_of, data, totals }`, or `{ as_of, data, pagination }` where they page. `as_of` is echoed like everywhere else.
- **No chart library.** Every chart here is one series: bars in a table, a range strip per row, and a twelve point line. Each is a few lines of inline SVG. Recharts would be a dependency for one line chart. One series also means the categorical palette `02` flagged is still not needed: every chart uses `--chart-1`.

---

## Phase 1: Editable multiplier

`app/controllers/api/v1/countries_controller.rb`, `app/services/countries/update.rb`, `app/serializers/country_serializer.rb`, `app/models/country.rb`.

- `PATCH /api/v1/countries/:id` takes `employer_cost_multiplier` and nothing else. Code and name are the closed set's identity, and changing them is a seed or console job.
- `Countries::Update` is `country.update!(attrs)`, per the service rules in `01`.
- `audited` on `Country`. The spec says every write records who changed what, and a multiplier edit moves every loaded number in the app.
- `CountrySerializer` gains `employer_cost_multiplier`. Rails renders a `BigDecimal` as a string, `"1.45"`, and that stays: a JSON number is a float in the client. The SPA displays it and sends a string back.
- The model already validates `> 0` and `< 100`. The column is `decimal(6,4)`, so a fifth decimal place rounds on save. Validate the scale instead, so `1.45678` is a 422 rather than a silent `1.4568`.

**Verify:** request specs for the update, a 422 on zero, on 100, and on five decimal places, the audit row carrying the user, and `code` in the body ignored.

---

## Phase 2: Run rate

`app/models/employee/analytics.rb`, `app/controllers/api/v1/analytics_controller.rb`.

```
GET /api/v1/analytics/run_rate?as_of&group_by=department|country|level
```

```sql
SELECT employees.department_id AS group_id,
       COUNT(*) AS headcount,
       COUNT(current_salary.amount_cents) AS salaried,
       COALESCE(SUM(current_salary.amount_cents), 0) AS gross_cents,
       COALESCE(SUM(ROUND(current_salary.amount_cents * countries.employer_cost_multiplier)), 0)::bigint AS loaded_cents,
       GROUPING(employees.department_id) AS is_total
FROM employees
JOIN countries ON countries.id = employees.country_id
LEFT JOIN LATERAL (...) current_salary ON TRUE
WHERE <active_as_of>
GROUP BY GROUPING SETS ((employees.department_id), ())
```

- `active_as_of` and the lateral both take the one `as_of` the request resolved.
- `COUNT(current_salary.amount_cents)` counts the salaried. `headcount - salaried` is the gap the UI shows.
- Each row carries `group` as `{ id, name }`, looked up from the closed set in the controller. Each is a small table, and a join per key would need its own select list. A group with no active employee does not appear. The UI shows the closed set, so a department with nobody in it reads as zero rather than missing.
- Rows are ordered by `loaded_cents DESC`, because "which department costs the most" is the question. The UI can re-sort on the client: at most a few dozen rows.
- The response is `{ as_of, group_by, data: [ { group, headcount, salaried, gross_cents, loaded_cents } ], totals: { headcount, salaried, gross_cents, loaded_cents } }`.
- Amounts in `amount_cents` are annual, so the sum is already annualized.

**Verify:** a model spec with hand-computed answers. A future-dated raise is ignored until `as_of` reaches it. A voided revision is ignored. An employee is counted on their exit date and not the day after. A pending hire is not counted. Two employees whose loaded amounts each round up show the per-row rounding. The totals equal the sum of the rows. `totals.headcount` equals the `pagination.total` of `GET /employees?status=active` on the same date.

---

## Phase 3: Distribution and cohorts

```
GET /api/v1/analytics/distribution?as_of&group_by=department|country|level|title
    &department_id[]&country_id[]&level_id[]&title&sort&page&per_page
```

- The filters are `Employee.filtered`'s id filters and `title`, applied before grouping. "The median for L4 engineers in India" is `group_by=level`, `department_id=<Engineering>`, `country_id=<India>`, and the L4 row. `q` and `status` are refused as 422: status is always active here, and a free text search makes a population nobody can name.
- Per group: `headcount`, `min_cents`, `p25_cents`, `median_cents`, `p75_cents`, `max_cents`. `headcount` here is the salaried count, since a percentile has nothing to say about someone with no salary. The response's `unsalaried` total says how many were left out.
- It pages, because `group_by=title` yields hundreds of rows. `total` is `COUNT(DISTINCT key)` over the same filtered population, passed to `paginate`. The other keys fit on one page and page anyway, so the client has one shape.
- `sort` is `name`, `headcount` or `median`, with `-` for descending. `name` is the key's natural order: department and country by `lower(name)`, level by `rank`, title by `lower(title)`. The default is `name`, except `title`, which defaults to `-headcount` so the titles most people hold come first. Every sort ends on the group key, for the same reason every employee sort ends on `id`.
- A group of one is shown. Its percentiles are all the one salary, which is true. The five person rule belongs to outliers, not to describing pay.

**Verify:** percentiles on a group of salaries whose p25 interpolates between two values, rounded half up. Filters narrowing the population before grouping. `title` paging. An unknown `group_by` or `sort` giving 422. `q` giving 422.

---

## Phase 4: Outliers

```
GET /api/v1/analytics/cohorts?as_of
GET /api/v1/analytics/outliers?as_of&department_id[]&country_id[]&level_id[]&direction=above|below&page&per_page
```

`cohort_stats` is the CTE both read, over the same active and salaried population, grouped by `level_id, country_id`:

```sql
SELECT level_id, country_id, COUNT(*) AS headcount,
       percentile_cont(0.25) WITHIN GROUP (ORDER BY amount_cents) AS p25,
       percentile_cont(0.5)  WITHIN GROUP (ORDER BY amount_cents) AS p50,
       percentile_cont(0.75) WITHIN GROUP (ORDER BY amount_cents) AS p75
```

- The fence is `p25 - 1.5 * (p75 - p25)` and `p75 + 1.5 * (p75 - p25)`, computed from the unrounded percentiles. Rounding first can move someone across the fence by a cent.
- Outside means strictly outside. A salary exactly on the fence is not flagged: the spec says below and above.
- **`/cohorts`** returns every level and country pair that has at least one salaried active employee: `headcount`, the three percentiles, both fences, `outliers_below`, `outliers_above`, and `evaluated`. A cohort under five has `evaluated: false`, null fences, null outlier counts and `reason: "fewer than 5 people"`. So does a cohort whose p25 equals its p75, with `reason: "p25 and p75 are equal"`: both fences would sit on the median, and a salary one cent above it would be flagged. Either one says so rather than being left out. It does not page: seven levels and nine countries is 63 rows at most.
- **`/outliers`** returns employees outside their fence, in evaluated cohorts only. Each carries the employee's id, name, department, level and country, `amount_cents`, `cohort_median_cents`, `cohort_headcount`, `direction`, and `distance_pct`. `distance_pct` is `(amount - median) / median * 100`, rounded to one decimal, negative below. It is the number the manager acts on, so it is what the list sorts by: `ABS(distance) DESC`, then `employees.id`.
- The filters apply after the join to `cohort_stats`, never inside it. The fence belongs to the whole cohort.

**Verify:** a cohort of four is not evaluated and says why. A cohort of five with one salary far above is flagged, and one exactly on the fence is not. A department filter removes rows from `/outliers` and leaves `/cohorts` unchanged. `distance_pct` is negative below the median. An exited employee is in no cohort. The median in `/cohorts` equals the median `/distribution` reports for the same level and country.

---

## Phase 5: Twelve months

```
GET /api/v1/analytics/trend?as_of
```

Thirteen points, so twelve intervals: the last day of each of the twelve months before `as_of`'s month, then `as_of` itself. `as_of` may be mid-month, and it is the point the manager asked about, so it is the last point rather than being rounded to a month end.

- Per point: `date`, `headcount`, `salaried`, `gross_cents`, `loaded_cents`. The same run rate query, driven by `generate_series` over the dates instead of one `as_of`. One query, not thirteen requests.
- Per interval, attached to the point that closes it: `hires` and `exits` dated inside it, and `raises` and `raise_delta_cents` from live revisions effective inside it that have a previous live revision, which excludes starting salaries. The delta comes from `SalaryRevision::PREVIOUS_AMOUNT`, the `LAG` `history_for` uses. A filter chained onto the window hides rows from `LAG`, so the interval date filter goes in an outer query. A backdated void changes these numbers, which is correct: they are a re-read of the dates, like everything else here.
- `generate_series` over `date` returns `timestamptz`, which depends on the session time zone. Cast back to `date` so the lateral compares dates.
- Month ends come from `date_trunc('month', d) + interval '1 month' - interval '1 day'`, so February ends on the 28th or 29th and not on the 30th.

**Verify:** the thirteen dates for an `as_of` of 2026-03-31, 2026-03-15 and 2024-02-29. Each point's headcount and run rate equal Phase 2's answer at that date. A hire on the first of a month counts in that month's interval. A starting salary is not a raise.

---

## Phase 6: Performance

The spec's budget is 300 ms at p95 for list, search and filter, server side, against seeded data. It asks only that dashboards stay fast. This plan holds them to the same budget.

- The lateral is the index scan `01` already tuned. The run rate is one pass of it over 10,000 employees. The trend is thirteen passes.
- `EXPLAIN ANALYZE` each answer against 10,000 seeded employees, and read the `Completed` time over twenty requests from the development log. The trend is the one at risk. If it misses, the fix is to compute the month-end points from one ordered scan of `salary_revisions` with a window, not a cache: a cache is a staleness bug the spec's "re-read of the same rule" argues against.
- No new index is expected. If one is, it is written into this plan with the plan that justified it.

**Verify:** each endpoint under 300 ms at p95. The numbers go into this file, under this phase.

---

## Phase 7: API contract

- Routes under `namespace :analytics` inside `api/v1`, one controller, `Api::V1::AnalyticsController`, one action per answer.
- Request specs in rswag's DSL for every endpoint, with a 422 for each closed-set param and a bad `as_of`.
- `RAILS_ENV=test bin/rails rswag`, then `npm run api:types` in `web/`. Both files are committed. `bin/ci` diffs `swagger/` only, so `schema.d.ts` is regenerated by hand.

---

## Phase 8: SPA

Routes, under the app layout, with `as_of` retained like everywhere else:

```
/analytics                  ?basis &group_by
/analytics/distribution     ?basis &group_by &department &country &level &title &sort &page
/analytics/outliers         ?department &country &level &direction &page &tab
/settings/countries
```

`basis` is `gross` or `loaded`, default `loaded`, because cost comparisons across countries are the reason the multiplier exists. It is in the URL so a shared link shows the same number. The header gains Analytics and Settings links.

Files follow `02`: `src/pages/routegen/analytics/index.page.tsx`, `analytics/distribution/index.page.tsx`, `analytics/outliers/index.page.tsx`, `settings/countries/index.page.tsx`, each with its `data.ts`. The basis toggle and the range strip are shared by the analytics pages, so they sit at `routegen/analytics/`.

### Overview

- A stat row: active headcount, run rate, and the salaried gap when there is one: "3 active employees have no salary on file". The list has no filter for that yet, so the gap is a number, not a link.
- Run rate by department, country or level: a table with a bar per row, headcount, and the amount. Groups with nobody active show as zero. Each row links to `/employees` filtered to that group and `status=active`, which is how the manager goes from "Engineering costs the most" to who is in it.
- Twelve months: one line for run rate on the chosen basis, and headcount, hires, exits and raises per month in a table under it. The line is inline SVG with a tooltip per point.
- Every loaded figure carries "at current employer cost rates".

### Distribution

- A table: group, headcount, and a range strip showing min, p25, median, p75 and max on one shared scale, with the median as a figure beside it. One shared scale across rows is the point: it is how the manager sees that L5 in India sits under L4 in France.
- Filters are the list's faceted filters and the title typeahead. Slice by department, country, level or title.
- Gross only. Percentiles are about what people are paid, and the multiplier does not change anyone's rank within a country.

### Outliers

- Two tabs. **People**: name, level, country, department, salary, cohort median, and distance as a signed percent. The name links to the employee. **Cohorts**: a level by country grid, each cell showing headcount and outlier count, and "not evaluated, fewer than 5 people" in the cells that are not.
- Filters narrow the people, and the page says the cohort is always the whole level and country.

### Countries

- One row per country: code, name, multiplier. Edit inline, save per row. The input is a decimal string with at most four places, validated with zod, sent as a string.
- The save toast says what it moves: "Fully loaded figures now use 1.45 for France, including past months."

### Money and numbers

The client still never sums money. Every total comes from the API. Bar lengths and strip positions are the only arithmetic, and they are display only. Percent is formatted with one decimal and a sign.

**Verify:** tests that the URL's search becomes the request params on each page, that `basis` switches the figures without a request, and that a 422 on the multiplier lands on its row. By hand against 10,000 seeded employees: find the most expensive department on loaded, then on gross, and see the order change. Find the median for L4 in Engineering in India. Open an outlier and check their salary against the cohort. Edit France's multiplier and see the loaded run rate move and the gross one stay. Move `as_of` past a future-dated raise and see the run rate and the trend's last point move with it.

---

## Phase 9: Docs and CI

- `README.md` and `CLAUDE.md`: the analytics endpoints and the multiplier edit, only where they list endpoints today.
- `docs/requirements.md` does not change. Spend is deferred, not dropped.

**Verify:** `bin/ci` green, `npm run build`, `npm run lint`, `npm test`.

## Verification

From a clean state:

```sh
docker compose up -d --wait postgres
bin/setup --skip-server
bin/dev                               # :3000
cd web && npm install && npm run dev  # :5173
```

Sign in as `hr@example.com` and walk Phase 8 by hand. Must pass: `bundle exec rspec`, `bin/ci`, and the web checks.

## Notes for later plans

- Spend for a period lands with one-time payments. It needs the register's pro rata, so build that once, as a scope that yields segments per employee per day range, and have both the register and spend sum it.
- Spend's loaded figure uses the current multiplier too, and says so, the same as here.
- The trend's per-interval deltas are the start of a pay movement report by reason. `SalaryRevision::REASONS` is already there to group on.
