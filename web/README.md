# web

Single-page frontend for the SMS salary management API. React 19, TypeScript, Vite 8, Tailwind CSS v4, shadcn components on Radix.

## Development

```sh
npm install      # needs Node ^20.19 || >=22.12, per package.json engines
npm run dev      # http://localhost:5173
```

The API is a separate application at the repo root. It must be running on http://localhost:3000. No dev-server proxy is configured, so requests go straight to the API's origin. The API allows this origin via `CORS_ORIGINS`.

## Scripts

| Command | Does |
| --- | --- |
| `npm run dev` | Vite dev server with HMR |
| `npm run build` | `tsc -b` then `vite build` into `dist/` |
| `npm run lint` | oxlint |
| `npm run preview` | Serve the production build locally |

There is no test runner and no formatter.

## Conventions

- Import through the `@/` alias (`@/lib/utils`, `@/components/ui/button`), not deep relative paths. It is defined in `vite.config.ts`, `tsconfig.json`, and `tsconfig.app.json`.
- Tailwind v4 is CSS-first. Theme tokens live in `src/index.css` via `@theme inline`. There is no `tailwind.config`.
- Add shadcn components with `npx shadcn@latest add <component>`. `components.json` puts them in `src/components/ui`, using the `radix-nova` style and a `neutral` base color.
- `src/lib/utils.ts` re-exports `cn` from the [`cn`](https://www.npmjs.com/package/cn) package, rather than defining the usual clsx + tailwind-merge helper. Leave it as is. shadcn's generated components import `cn` from here.
- `strict` is not enabled in `tsconfig.app.json`. `noUnusedLocals`, `noUnusedParameters`, and `verbatimModuleSyntax` are.

## Deployment

`dist/` is a static bundle. It deploys independently of the Rails image. The root `.dockerignore` excludes `/web` entirely, so nothing in this directory reaches it. Whatever origin serves `dist/` must be listed in the API's `CORS_ORIGINS`.
