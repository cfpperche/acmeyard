# Stack defaults — research cache

**Retrieved:** 2026-05-17
**Re-research cadence:** quarterly (next: 2026-08-17)
**Sources consulted:** https://nextjs.org/docs/app/getting-started/installation (Next.js 16.2.6 docs, lastUpdated 2026-05-13); https://docs.expo.dev/get-started/create-a-project/ + https://docs.expo.dev/router/installation/ (Expo SDK 55 docs)

This file is the source of truth for the `/prototype` skill's stack recommendations. When a founder doesn't supply `--stack=<name>`, Phase 1 discovery recommends per the platform target below. Templates in `templates/monorepo-skeleton/<stack>/` must match the versions + structure documented here; drift means re-snapshot is overdue.

## Recommendation by platform target

| Platform target | Recommended stack | Rationale |
|---|---|---|
| **web** | Next.js 16 + React 19 + Tailwind 4 + Biome | App Router default, Turbopack default bundler, Biome chosen over ESLint for unified format+lint, Tailwind included for fast UI iteration |
| **mobile** | Expo SDK 55 + React Native + expo-router + NativeWind | expo-router is the recommended typed-routes router since SDK 50+; NativeWind brings Tailwind utility-class authoring to RN (community-standard, not officially endorsed by Expo but widely used) |
| **desktop** | Tauri 2 + React + Tailwind (deferred — v1 ships web + mobile only per spec.md non-goal) |
| **CLI** | bun + TypeScript + commander or @clack/prompts (deferred — same) |

## Next.js 16 stack (web)

**Canonical scaffold (use this when bundling templates):**
```bash
pnpm create next-app@latest my-app --yes
# Defaults: TypeScript, Tailwind CSS, ESLint, App Router, Turbopack, AGENTS.md, import alias @/*
```

**Manual scaffold (matches what `templates/monorepo-skeleton/next/` bundles):**
```bash
pnpm i next@latest react@latest react-dom@latest
pnpm i -D typescript @types/react @types/node tailwindcss @tailwindcss/postcss @biomejs/biome
```

**File structure (canonical, app router):**
```
my-app/
├── package.json
├── tsconfig.json
├── next.config.ts            (or .mjs/.js)
├── biome.json
├── postcss.config.mjs        (Tailwind 4 uses this — no separate tailwind.config required for default tokens)
├── app/
│   ├── layout.tsx            (root layout — required, must include <html> + <body>)
│   ├── page.tsx              (home)
│   └── globals.css           (Tailwind imports)
├── public/                   (static assets)
└── README.md
```

**package.json scripts (binding for monorepo `pnpm dev`):**
```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "typecheck": "tsc --noEmit",
    "lint": "biome check .",
    "format": "biome format --write ."
  }
}
```

**Key version notes:**
- Node.js 20.9+ required
- React 19 stable (App Router uses React canary internally; declare `react` and `react-dom` in package.json anyway for tooling compat)
- Next.js 16: `next build` no longer runs the linter — `pnpm lint` is a separate script call (downstream typecheck+lint verification in spec.md plain bullet "two-stack dogfood verified" depends on this)
- Turbopack is default; Webpack is `next dev --webpack` if needed
- Tailwind 4: PostCSS-only setup (no `tailwind.config.ts` required for defaults; only needed for custom theming)
- Biome chosen over ESLint: single tool for lint+format, faster, less config

**Why pnpm over npm/yarn/bun:** Workspace support out of the box (matters when scaling beyond 1 package); deterministic lockfile; smaller node_modules via content-addressable store.

## Expo SDK 55 stack (mobile)

**Canonical scaffold:**
```bash
npx create-expo-app@latest my-app --template default@sdk-55
# Note: without --template flag, SDK 54 is created during transition period
```

**Manual scaffold (matches what `templates/monorepo-skeleton/expo/` bundles):**
```bash
bun add expo react react-native
bun add expo-router react-native-safe-area-context react-native-screens expo-linking expo-constants expo-status-bar
bun add -D typescript @types/react
bun add nativewind tailwindcss@^3  # NativeWind 4 currently uses Tailwind 3 — verify when re-snapshotting
```

**File structure (canonical, expo-router):**
```
my-app/
├── package.json
├── tsconfig.json             (extends expo/tsconfig.base)
├── app.json
├── babel.config.js
├── nativewind-env.d.ts
├── tailwind.config.js        (NativeWind brings its own config)
├── app/
│   ├── _layout.tsx           (root layout — equivalent of Next.js root layout)
│   └── index.tsx             (home screen)
├── assets/                   (icons, splash, fonts)
└── README.md
```

**package.json scripts (binding for monorepo `bunx expo start` or `pnpm dev` aliased):**
```json
{
  "scripts": {
    "start": "expo start",
    "dev": "expo start",
    "android": "expo start --android",
    "ios": "expo start --ios",
    "web": "expo start --web",
    "typecheck": "tsc --noEmit",
    "lint": "biome check ."
  }
}
```

**Key configuration:**
- `app.json` MUST include `"scheme": "<app-name>"` for deep linking (expo-router requirement)
- `app.json` MUST include `"experiments": { "typedRoutes": true }` for type-safe routes
- For web target: `app.json` needs `"web": { "bundler": "metro" }`
- `tsconfig.json` extends `expo/tsconfig.base`; for `@/*` aliasing, paths map to `./app/*` (or `./src/*` if you use `src/` layout)

**Why bun over npm for Expo:** Faster install, native TS runtime for dev scripts. Expo doesn't have official bun preference but works fine in 2026.

## Brand defaults (when `--skip-brand` is set)

Use `templates/default-tokens.css` — neutral semantic CSS custom properties (`--color-primary`, `--space-md`, `--radius-md`, etc.). Same file is consumed by both stacks: Next.js imports via `app/globals.css`; Expo + NativeWind reads via `tailwind.config.js` extending the same token names.

## Drift signals to watch for

When re-researching quarterly, check:
- Next.js major version bump (16 → 17 changes default bundler / router conventions)
- Tailwind major version (4 → 5 may change PostCSS setup)
- Expo SDK numeric bump (each SDK release deprecates one or two prior SDKs)
- React major version (React 19 → 20 affects React Native compatibility window)
- Biome major version (config schema evolves)
- NativeWind major version (currently locked to Tailwind 3; tracking Tailwind 4 support is in progress)
- expo-router major version (typed-routes API can shift)

When any of the above changes materially, re-snapshot this file, bump the date stamp, and audit `templates/monorepo-skeleton/<stack>/` for staleness.
