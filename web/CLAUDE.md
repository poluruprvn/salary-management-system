# CLAUDE.md: web/

Frontend SPA. Root `CLAUDE.md` covers the backend.

The API contract is OpenAPI 3, generated from the backend's request specs into `swagger/v1/openapi.yaml`. With the API running in development, Swagger UI serves it at `http://localhost:3000/api-docs`. Read it there rather than guessing a shape. Paginated collections return a `{ data, pagination }` envelope, with `Link` and `X-Total-Count` also set as response headers. Unpaginated ones return `{ data }`.

## State of this directory

`src/App.tsx` and `src/App.css` are the untouched Vite starter page. The CSS is plain and hand-written, not Tailwind, and references a sprite at `public/icons.svg`. Replace both when building real screens. Do not treat `App.css` as the styling precedent.

Not yet chosen: router, data fetching/API client, state management, test runner.

Nothing reads `import.meta.env`, so there is no API base URL variable yet. The API is at `http://localhost:3000`. Its `CORS_ORIGINS` must list whatever origin this app is served from.

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

Generated components import `cn` from `@/lib/utils`, which re-exports it from the `cn` package. Do not swap that for a hand-written clsx + tailwind-merge helper.

## Conventions

Single quotes, no semicolons, 2-space indent. There is no formatter, so match the surrounding file. `src/lib/utils.ts` uses double quotes; it is the outlier.

Never write complex prose. In docs, comments, commit messages, and PR descriptions: short sentences, plain words, one idea each. No hedging, no filler, no rhetorical flourish. No em dashes; use a colon, a comma, or a full stop.

Comments stay short and to the point. Explain why, not what: a workaround, a spec quirk, a tradeoff. Do not restate the code, narrate a change (`// added this`), or add docstrings to a file that does not already use them.

Keep commit messages short. A one-line description of what changed is enough.
