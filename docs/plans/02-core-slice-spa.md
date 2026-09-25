# Salary management: core slice SPA

## Context

`docs/requirements.md` is the spec. `01-core-slice.md` built the API: sign in, employees, salary revisions, the audit trail and the closed sets. `web/` is still the Vite starter page.

This plan builds the screens for that API and nothing more. Later plans add payments, employer cost, analytics, the register, and import and export, each with its own screens. Four things here must not need rewriting, because every later screen sits on them: the API client, the session, `as_of`, and the list's URL state.

## Decisions

- **TanStack Router, with the route tree in code.** The list's state is its URL: search, filters, sort, page and `as_of`. TanStack Router validates and types search params per route. React Router hands back strings. There are five routes, so file based routing would add a Vite plugin and a generated file for nothing.
- **No data library.** The app route's loader fetches what every screen reads: `meta`, `me` and the closed sets. The router keeps them for an hour. Each screen loads the rest through `useApi`, a small hook over the API client. It loads when its key changes, keeps the last data on screen while the next loads, and aborts a request that is no longer wanted. Every write goes through `write`, which reloads whatever is on screen when it succeeds.
- **zustand holds client state:** the session, the last list search and the write count, nothing else. The fetch wrapper reads and rotates tokens outside React, which a store's `getState` allows and a context does not. Server data never goes into a store.
- **The file layout follows the pug app.** Each page is `src/pages/routegen/<path>/index.page.tsx`, with a `[param]` folder for a path param. Its parts sit next to it: components, helpers, its store, and its API calls in `data.ts`. Parts that several of a feature's pages use sit at the feature's root, like `routegen/employees/employee-form.tsx`. `pages/router.tsx` lists the routes by hand, because TanStack Router types search params only on a route tree built in code. Sign in is `pages/sign-in.tsx`, outside `routegen`, because it runs without a session. `api/` holds the fetch layer and the typed clients, `auth/` the session, `data/` what every screen reads, and `components/layout/` the shell. `components/`, `hooks/` and `lib/` hold only what several features share.
- **The API client is generated from the contract.** `openapi-typescript` turns `swagger/v1/openapi.yaml` into `src/api/schema.d.ts`, and `openapi-fetch` checks every call against it: path, params, body and response. A changed endpoint fails `tsc`, not a screen. The file is committed, and `bin/ci` regenerates and diffs it, like the OpenAPI step. `openapi-typescript` declares a peer of TypeScript 5, so `package.json` overrides it to the project's 6.
- **Forms are react-hook-form and zod**, on shadcn's `field` components. The server stays the authority. The client checks what it knows without a round trip, and a 422's `details` land on the fields they name.
- **`strict` goes on first**, before any component exists.
- **Dates are native `<input type="date">`.** It emits `YYYY-MM-DD`, the API's format, and typing a 2014 hire date beats paging a calendar back twelve years. No date library. Display goes through `Intl.DateTimeFormat` with `timeZone: "UTC"`, or `2026-03-01` renders as Feb 28 anywhere west of Greenwich.
- **Money stays integer minor units.** Input is parsed as a string into cents, never `parseFloat(x) * 100`: `1.005 * 100` is `100.49999999999999`. Display divides by `10 ** minor_unit`, which is exact to the cent for every amount the API accepts. The client never sums money. The change, as an amount and a percent, is its only arithmetic, and that is display only.
- **Tests are Vitest, Testing Library and MSW**, in jsdom. No browser runner: the flows worth a browser are checked by hand against the seeded API, per Verification.

### The session

Sign in returns an access token, its lifetime and a refresh token.

- The access token lives in memory only. A reload refreshes to get a new one.
- The refresh token lives in `localStorage`, through zustand's `persist`. The API has no cookies, so the choice is JS readable storage or signing in on every reload. An XSS can read it, and that is the accepted cost. React escapes output, nothing uses `dangerouslySetInnerHTML`, and every refresh rotates the token. `sessionStorage` would sign the manager out of every new tab, and opening employees in tabs is normal use.
- A request refreshes first when the access token has under 30 seconds left. A 401 with `token_expired` refreshes and retries once. Any other 401 ends the session. So does a refresh the API refuses with a 401. Any other failed refresh keeps it.
- Refresh is single flight. In a tab, concurrent requests share one promise. Across tabs, `navigator.locks` serializes it, and the stored refresh token is re-read inside the lock. Without the lock two tabs refresh with the same token, the server rotates it once, and the loser gets `invalid_refresh_token` and signs out.
- Sign out calls the API, then clears the store and the last list search. The pages unmount, and the app route keeps no loader data past the session, so no salary or name stays in memory. A refresh that lands after a sign out is dropped. Other tabs see the storage event and sign out too.

### `as_of`

Every read that takes `as_of` sends it explicitly, never by omission.

- It lives in the URL, so a shared link reproduces the view. It is left out when it equals the server's today, so a bookmark means today and not the day it was saved.
- With none in the URL, the client sends `meta.today`, not the browser's date. The server's today is UTC, and in IST the two disagree until 05:30. The app route keeps `meta` for an hour, so in a tab left open overnight the next navigation moves to the new day. The header always shows the date in use.
- It is retained across links (`retainSearchParams`), so opening an employee from a list as of June shows them as of June.
- The header's date input commits on blur, on Enter, or after an 800 ms pause, and only a year from 1900 to 2099. Chrome fires `change` per keystroke in the year segment, and year `0002` is a valid request. Left empty or out of range, it shows the date in use again.

## Routes

```
/sign-in                     ?redirect=
/                            redirects to /employees
/employees                   ?q &department &country &level &status &title &sort &page &per_page
/employees/new
/employees/$employeeId       ?tab &changes_page
```

`as_of` rides on all but `/sign-in`. Everything but `/sign-in` sits under one pathless layout route. Its `beforeLoad` sends a visitor with no refresh token to `/sign-in?redirect=<where they were>`, and its loader fetches `meta`, `me` and the three closed sets, and keeps them for an hour. Filters, forms and the change log all read those. `redirect` is honoured only when it starts with one `/`, and not `//` or `/\`, so sign in cannot bounce the manager to another origin.

Search params go through a zod schema per route, and one that does not parse falls back to its default rather than throwing. Defaults are stripped from the URL, so the plain list is `/employees`.

## Screens

### Employees

- **Search** is debounced 300 ms into `q`, and replaces the history entry rather than pushing one, so Back does not replay keystrokes. Any change of search, filter, sort or page size goes back to page 1.
- **Filters**: department, country and level are multi-select popovers over the closed sets. Status is a segmented control: all, active, pending, exited, as of `as_of`. Title is an exact match chosen from the title typeahead. A reset clears them all.
- **Columns**: name with email under it, title, department, country, level, status, hire date, exit date, salary. The name is a link. A click elsewhere on the row follows it, unless it ends a text selection. Every sort key the API has is a sortable header with `aria-sort`: first click ascending, second descending. Salary is right aligned in tabular figures, and `—` when no salary is in force on `as_of`: the employee is not active then, which the status column explains, or has none on file yet.
- **Paging** shows numbered pages with ellipses, first and last, and 25, 50 or 100 per page. Jumping to a page is the reason the API pages by offset, so the control offers it. The previous page stays on screen while the next loads. A page past the end shows no rows and a link to the last page.
- The page writes its search into zustand, and the employee page's back link reads it. Back to list returns to the same filters and page.

### Employee

- **Header**: name, email, title, status and current salary as of `as_of`, with the date it took effect. Department, country, level, hire and exit dates below. Actions: edit, and add revision.
- **Salary history**: every live revision, newest first. Effective date, salary, previous salary, change as an amount and a percent, reason, note. The revision matching `current_salary.effective_date` is marked in force. One dated after `as_of` is marked scheduled. That is the spec's "the previous value stays visible after it": a raise adds a row and leaves the old salary on the row before it. Each row can be corrected or voided.
- **Add revision**: new annual salary, effective date, reason, note. As the date changes, the form shows the salary in force before it, the new salary, and the change as an amount and a percent, from the history already loaded. The toast after saving reads `$132,000 from Mar 1, 2026` and `$120,000 to $132,000, +10.0%.`, from `previous_amount_cents` in the response, which is the server's answer. The first revision defaults its date to the hire date, its reason to `market_adjustment` and its note to `Starting salary`, which is how the seed records a starting salary. Later ones default to today, moved into the employment when today falls outside it, with reason `merit`.
- **Correct** is the same form, filled in, sending only what changed. It says what it is for: fixing a mistake, not a raise.
- **Void** asks first, and says the row stays in the change log.
- Any write reloads what is on screen. A backdated revision changes the previous amount of the one after it, and the list's salary column too.
- **Change log**: `GET .../audits`, paged. Each entry is when, who, what, and the changed fields as old to new. Values render by field: `amount_cents` as money, the three ids through the closed sets, dates as dates, `reason` by its label. `voided_at` is not a field: it names the entry Voided, or Restored when cleared. A null user shows as System, which is the seed or a console.

### New and edit

One employee form. `/employees/new` posts it and opens the new employee. Edit is a dialog on the employee page that sends only changed fields, and clearing the exit date sends `null`.

The title field is a typeahead over `GET /titles?q=`, debounced 200 ms, showing how many people hold each title. It stays free text.

Creating an employee does not set a salary. No endpoint does both in one transaction, and two requests can half fail. The new employee's history is empty and offers "Add starting salary".

### Errors

`ApiError` carries status, code, message and details. A load error shows its message with a retry. A mutation's 422 details go to `setError` on the named field. Rails names a `belongs_to` error by the association, `country`, not the column, `country_id`, so each form's field map translates those three. `base`, an unknown field, and the empty details of a unique index race show as one alert above the form. Nothing retries on its own. A network error says the API could not be reached. Offline, a request fails at once rather than waiting in silence. A failed reload keeps the data on screen, and any dialog open on it.

## Phase 0: Harness

- `tsconfig.app.json`: `"strict": true`.
- Delete the starter: `App.tsx`, `App.css`, `src/assets/`, `public/icons.svg`. Title the page.
- Dependencies: `@tanstack/react-router`, `zustand`, `openapi-fetch`, `react-hook-form`, `zod`, `@hookform/resolvers`. Dev: `openapi-typescript`, `vitest`, `jsdom`, `@testing-library/react`, `@testing-library/user-event`, `@testing-library/jest-dom`, `msw`.
- Scripts: `test` (`vitest run`), `api:types` (regenerates `src/api/schema.d.ts`).
- `VITE_API_URL`, default `http://localhost:3000`, typed in `src/vite-env.d.ts`.
- Vitest in `vite.config.ts`, with a setup file for jest-dom, the MSW server, and what jsdom lacks: `ResizeObserver`, pointer capture and `scrollIntoView` for Radix and cmdk, and `matchMedia` for sonner. Tests run in `America/Los_Angeles`, so a date printed in local time rather than UTC fails.
- shadcn components as the screens need them, through `npx shadcn@latest add`.

**Verify:** `npm run build`, `npm run lint` and `npm test` pass on an empty app.

## Phase 1: API client and session

`src/api/transport.ts`, `src/api/client.ts`, `src/api/types.ts`, `src/auth/session.ts`, `src/auth/auth.ts`, `src/hooks/use-api.ts`.

- `transport.ts` is the custom `fetch`. It sends the access token, refreshes it, and clones the request before sending, so a retry has a body to send. `client.ts` builds the `openapi-fetch` clients on it, and `unwrap` turns a response into its data or throws `ApiError`.
- `types.ts` aliases the schemas: `Employee`, `SalaryHistoryEntry`, `Pagination`, and the rest. Screens import these, not `components["schemas"]`.
- `session.ts` is the zustand store from Decisions, and `auth.ts` signs in and out.

**Verify:** unit tests for money formatting and parsing, date formatting, and the session: a missing access token refreshes before the first request, two concurrent requests refresh once, `token_expired` retries once, a refused refresh clears the session, and sign out clears the store.

## Phase 2: Routing, shell and sign in

`src/pages/router.tsx`, `src/App.tsx`, `src/main.tsx`, the layout in `src/components/layout/`, and `src/pages/sign-in.tsx`.

**Verify:** with the API running, `/employees` signed out goes to `/sign-in?redirect=/employees` and back after signing in. A wrong password says so. A reload keeps the session. Sign out in one tab signs out the other.

## Phase 3: Employee list

**Verify:** tests that the URL's search becomes the request's params, that sort, filter and search write the URL and reset the page, and that past the end offers the last page. By hand against 10,000 seeded employees: find one by name, filter by department and level, sort by salary both ways with blanks last, jump to page 200, and change `as_of` to see salary and status move.

## Phase 4: Employee page, new and edit

**Verify:** tests that a 422 lands on its field, that `country` lands on the country select, and that edit sends only changed fields. By hand: create an employee, edit their title from the typeahead, set and clear an exit date.

## Phase 5: Salary history and revisions

**Verify:** tests that the form shows the salary in force before the chosen date, sends integer cents, and shows a 422 on an occupied date. By hand: add a raise dated next month, see it scheduled, move `as_of` past it and see it in force and in the list. Correct it, void it.

## Phase 6: Change log

**Verify:** by hand, the edits and revisions above appear newest first, with the HR user as the actor and names instead of ids.

## Phase 7: CI and docs

- `config/ci.rb`: install, lint, test and build `web/`, then regenerate `schema.d.ts` from the committed OpenAPI file and fail on a diff. That step runs after the OpenAPI step, so the chain is request specs, then OpenAPI, then TypeScript.
- `web/CLAUDE.md`: the stack is chosen, `strict` is on, the directory layout, `VITE_API_URL`, how to regenerate the types.
- `web/README.md`, the root `README.md` and `CLAUDE.md`: the new scripts and checks.

**Verify:** `bin/ci` green.

## Verification

From a clean state:

```sh
docker compose up -d --wait postgres
bin/setup --skip-server
bin/dev                               # :3000
cd web && npm install && npm run dev  # :5173
```

Sign in as `hr@example.com`, then walk Phases 3 to 6 by hand. Must pass: `npm run build`, `npm run lint`, `npm test`, `bin/ci`.

## Notes for later plans

- Each later slice adds a folder under `src/pages/routegen/` and reuses `useApi`, `useAsOf`, `PageNav` and the list's search pattern.
- The tangerine theme's `--chart-1` through `--chart-5` are four blues and an orange. That reads as a ramp, not five categories, so the analytics plan needs a categorical palette before its first chart.
- The SPA sets no Content-Security-Policy. Whatever serves `dist/` should, with `connect-src` naming the API origin. It is the main guard on a refresh token in `localStorage`.
