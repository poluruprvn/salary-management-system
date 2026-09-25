# CLAUDE.md: web/

Frontend SPA. Root `CLAUDE.md` covers the backend.

The API contract is OpenAPI 3, generated from the backend's request specs into `swagger/v1/openapi.yaml`. With the API running in development, Swagger UI serves it at `http://localhost:3000/api-docs`. Read it there rather than guessing a shape. Paginated collections return a `{ data, pagination }` envelope, with `Link` and `X-Total-Count` also set as response headers. Unpaginated ones return `{ data }`.

## Stack

- Routing: TanStack Router. Every route is declared by hand in `src/pages/router.tsx`, with a zod schema for its search params. Page files sit under `src/pages/routegen/`, named `index.page.tsx`, with the page's `data.ts` and `search.ts` beside it.
- API client: `openapi-fetch`, typed by `src/api/schema.d.ts`. Regenerate it with `npm run api:types` after the OpenAPI file changes. `src/api/types.ts` names the shapes pages use.
- Data fetching: `useApi` in `src/hooks/use-api.ts`, not TanStack Query. It refetches after any write. On a failed reload it keeps the last data and sets `error`, so show the error whenever `error` is set.
- State: zustand, for the session only (`src/auth/session.ts`). Everything a page shows is in the URL.
- Forms: react-hook-form with zod. `applyApiErrors` puts a 422's details on the fields.
- Charts: shadcn's `chart` on Recharts, for the trend line only.

The API base URL is `VITE_API_URL`, default `http://localhost:3000`. The API's `CORS_ORIGINS` must list whatever origin this app is served from.

## Testing

`npm test` runs vitest in jsdom with `TZ=America/Los_Angeles`, so a date printed in local time instead of UTC fails. MSW serves the API: default handlers in `src/test/server.ts`, data in `src/test/fixtures.ts`. Override a handler per test with `server.use`. `renderApp(path)` in `src/test/render.tsx` mounts the whole router at a URL, signed in by default. The toaster is not mounted, so toasts cannot be asserted.

## Type checking

`npm run build` typechecks (`tsc -b`). `npm run lint` (oxlint) does not. The tsconfig is the Vite react-ts template's. Its defaults differ from what most TypeScript code assumes:

- `verbatimModuleSyntax`: type-only imports must be written `import type { Foo } from '...'`.
- `erasableSyntaxOnly`: no enums, no `constructor(private x)` parameter properties, no namespaces.
- `noUnusedLocals` / `noUnusedParameters`: unused bindings fail the build, not just the lint.
- `allowImportingTsExtensions`: relative imports include the extension (`./App.tsx`), matching existing code.
- `strict` is not set, so `null` and `undefined` are not tracked. Write code that would survive it being turned on.

oxlint runs the `react`, `typescript`, and `oxc` plugins. Type-aware rules are off.

## Styling

Tailwind v4, configured entirely in `src/index.css`. There is no `tailwind.config`. `@theme inline` maps shadcn's CSS variables to utility names. Use semantic tokens (`bg-background`, `text-muted-foreground`, `border-border`, `rounded-lg`), not raw palette colors. Dark mode is the `.dark` class, not a media query.

Add components with `npx shadcn@latest add <name>`. `components.json` writes them to `src/components/ui` in the `radix-nova` style. Import via the `@/` alias.

Generated components import `cn` from the `cn` package. Hand-written code imports it from `@/lib/utils`, which re-exports it. Do not swap either for a hand-written clsx + tailwind-merge helper.

## Conventions

Single quotes, no semicolons, 2-space indent. There is no formatter, so match the surrounding file. `src/lib/utils.ts` and the generated `src/components/ui/*` use double quotes. They are the outliers.

Never write complex prose. In docs, comments, commit messages, and PR descriptions: short sentences, plain words, one idea each. No hedging, no filler, no rhetorical flourish. No em dashes; use a colon, a comma, or a full stop.

Comments stay short and to the point. Explain why, not what: a workaround, a spec quirk, a tradeoff. Do not restate the code, narrate a change (`// added this`), or add docstrings to a file that does not already use them.

Keep commit messages short. A one-line description of what changed is enough.
