# Requirements

## Goal

ACME tracks salaries for 10,000 employees across several countries in spreadsheets. Replace that with web software. The HR manager needs a trustworthy record of what each person is paid, and answers to questions about how the org pays people. The second is the harder half. Salary CRUD is table stakes.

## User

One persona: the HR manager. They own compensation for the whole org and may see every number in it.

## Model

1. **Salary is effective dated.** Amount, start date. A raise is a new record, not an edit. History, future dated raises, and "what did we pay in March" all fall out of that.
2. **One time payments are not salary.** Salary is a rate over a range. A bonus is an amount on a date. One table for both makes every total wrong.
3. **One currency.** Every amount is stored and reported in a single base currency. There is no conversion and no rate table. Country still changes what a person costs, but through the employer cost multiplier, not an exchange rate.
4. **Money is an integer count of minor units.** Cents, not 1.00. Floats do not sum to the same total twice across 10,000 rows, and a bank batch that does not foot is rejected.

## Scope

**Employees.** Number, name, email, country, department, title, level, hire date, exit date. Exit date is what makes a final month pro rate. Server side search, filter, sort, and pagination: 10,000 rows do not belong in browser memory.

Status is derived, not stored: pending before the hire date, exited after the exit date, active otherwise. It is always as of a date, which defaults to today. Stored status drifts from the dates it restates, and a derived one makes headcount at any past month end a re read of the same rule.

**Departments.** A table, not a text column. Free text drifts into "Eng" and "Engineering" and breaks every rollup.

**Levels and titles.** Level is a closed set, for the same reason as departments. Outliers and percentiles key on it, so a level that drifts breaks both. Title is free text, because the org has no job catalogue and hundreds of distinct titles are normal. Distribution does slice by title, so drift costs something here too: a median by title splits when someone types "Sr. Engineer" for "Senior Engineer". The input offers titles already in use instead of an empty box, which converges the set without anyone having to define one up front.

**Compensation.** Full history per employee. A revision carries amount, effective date, and a reason: merit, promotion, market adjustment, or correction. Effective dates may be in the future. The delta is computed, not stored.

**One time payments.** Bonus, signing bonus, spot award, or commission, on a date.

**Employer cost.** An editable `employer_cost_multiplier` per country. Cost views show gross and fully loaded. Without it, comparing a department in France against one in India is wrong by roughly 40 percent.

The multiplier is current only, not effective dated. Editing it moves every fully loaded number, including past months. That is the same trade already made for department history: the cost question is about now, and a dated multiplier buys accuracy nobody asked for. Fully loaded views say they are at current rates, so the number is never mistaken for what was booked at the time. Gross is untouched by this, and the register is gross, so a bank file never moves.

**Answers.**

- Annualized run rate, by department, country, and level. Gross or fully loaded, as of a date.
- Spend for a period: salary accrued plus one time payments made in it. Accrual pro rates the same way as the register.
- Pay distribution: median, p25, p75, and range, sliced by department, country, level, and title.
- Outliers: people paid far from the median for their level and country.
- Headcount and pay movement over twelve months.

Every answer is as of a date, which defaults to today. Run rate sums the salary in force on that date for everyone active then, and ignores revisions effective later. Moving the date forward is how the manager sees the run rate once approved raises land, so there is no separate switch for future raises. The same date drives derived status, so headcount and run rate always agree.

An outlier is someone outside the fence for their cohort: below p25 minus 1.5 times the interquartile range, or above p75 plus 1.5 times it. The cohort is level and country, active employees only. The fence reuses percentiles the distribution answer already computes, and it tightens on its own where pay is consistent, which a fixed percent band cannot do. What the UI shows is distance from the cohort median as a percent, because that is the number the manager acts on. A cohort under five people is not evaluated, and says so rather than being left out quietly. Quartiles on four people flag everyone or no one.

**Monthly payment register.** Pick a month, get one CSV per country, because a bank batch is per debit account. Per employee: salary accrued, one time payments, gross total. Pro rated on actual days when a revision, a hire, or an exit lands mid month. Amounts are gross and go to the payroll provider, who computes net and files the batch.

Pro rata is a fraction of the calendar days in that month. Someone on 120,000 a year earns 10,000 in a month, and hired on the 16th of a 30 day month is paid 15/30 of it. The denominator is days in the month, not 365, so a day in February is worth more than a day in March. Exit date is inclusive: the last day is paid. A revision effective on the 15th pays the old rate for the 1st to the 14th and the new rate from the 15th.

Each segment rounds to the minor unit once, half up. An employee's month is the sum of their segments, and a register total is the sum of its rows, never a figure computed on the side. Two segments that both round up can leave a month a minor unit above the unsplit salary. That is accepted. Rows that foot matter more than a month that matches to the cent.

A register is a draft until it is issued, and a draft recomputes freely. An issued register is frozen: the rows, the amounts, and the employee set. A revision, a hire, or an exit backdated into an issued month does not change it. It lands as an adjustment line on the next register, positive or negative, labelled with the month it belongs to. Without this, a correction entered in June rewrites the March file already sent to the provider, and nothing reconciles.

**Import and export.** CSV in for employees and salaries, because the data starts in Excel. CSV out for any filtered list.

Employees match on employee number, salaries on employee number and effective date. Both upsert, so re running the same file changes nothing and a fixed file can be uploaded again safely. A file is all or nothing: every row is validated first, and one bad row rejects the whole file with a report of row, column, and reason. Half an import leaves a state nobody can describe, and the manager's unit of thought is the file, not the row. A row naming a department or level that does not exist is an error, not a reason to create one, because that is the whole point of keeping them as closed sets.

**Sign in and audit.** Email and password, one seeded HR account: 10,000 salaries cannot sit behind a public URL. Every write records who changed what, and when.

The API is token based, because it is API only and has no sessions or cookies. Sign in returns two things: a short lived JWT access token, and a long lived refresh token held server side. The access token is stateless and is never looked up, so authentication costs a signature verify and no query. The refresh token is a row, and sign out deletes it.

That split is what makes sign out mean something. A JWT cannot be withdrawn once issued, so ending a session works by refusing to mint the next one. The cost is a window: after sign out the old access token still verifies until it expires. Keep the access lifetime short enough that the window does not matter, and accept it rather than pay for a blacklist on every request.

Audit rows are written in the same transaction as the write they record, so there is no window where a change exists and its trail does not.

**Seed data.** 10,000 employees across countries and departments, with plausible salary histories and bonuses.

## Out of scope

| Left out | Why |
| --- | --- |
| Payroll execution: payslips, withholding, net pay, bank files | A different product. Per country tax rules are most of the work and none of the insight. The register hands gross to a provider, which is the seam. |
| Employer tax as a modelled rule set | Real cost, but modelling it properly is a tax engine. The per country multiplier is the version worth having. |
| Benefits, equity, stock grants | Each needs its own vesting and valuation model. Salary and cash bonuses answer the questions asked. |
| Approval workflows, sign off | One persona, and they are the approver. State machines that add no information. |
| Roles, permissions, SSO, MFA, password reset | One persona who may see everything, so nothing to authorize against. Sign in itself is in scope. |
| Cursor or keyset pagination | Lists page by offset over `Link` and count headers. Offset degrades only at depth, and 10,000 rows is a few hundred pages. A cursor costs an opaque token per sort key, and it takes away jumping to a page, which is the one thing a manager scanning a list actually does. |
| A search engine: Elasticsearch, OpenSearch, Meilisearch | Search is `ILIKE` in Postgres, which stays inside the latency budget at 10,000 employees. A second datastore buys relevance ranking and fuzzy matching, and costs a sync path, a reindex path, and a class of staleness bug. Nothing in the questions above needs it. |
| Access token blacklists, denylists, refresh reuse detection | A blacklist is a database read on every request, which undoes the reason to carry a JWT at all. Sign out deletes the refresh token, so a session ends within one access token lifetime. Shorten that lifetime if the window ever matters. |
| Multi currency and FX | Every amount is in one base currency. Conversion needs a dated rate table, a rule for which rate a given query uses, and rounding on every aggregate. The questions asked are comparisons, and comparisons work in one currency. The cost is that the register hands the provider a base currency amount, not a local one. |
| Department change history | Only the current department is kept, so past cost attributes to today's department. The cost question is about run rate now. |
| Pay bands and compa ratio | Bands are a structure the org has not defined. Percentiles from actual pay answer it with data that exists. |
| Leave, PTO, holiday calendars, leave liability | A different domain. It reaches pay only through unpaid leave and encashment, and encashment is already a payment type. |
| Notifications, scheduled reports | The manager opens the app to ask a question. Nothing needs to push. |

## Done looks like

- Any of 10,000 employees is findable in seconds.
- A raise is one form, and the previous value stays visible after it.
- "Which department costs the most" and "what is the median for L4 engineers in India" are answerable in the UI, with no export.
- Lists and dashboards stay fast at 10,000 employees with full salary history behind them: list, search, and filter under 300 ms at p95, measured server side against seeded data.
