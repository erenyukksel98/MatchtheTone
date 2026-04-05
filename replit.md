# Workspace

## Overview

pnpm workspace monorepo using TypeScript. Each package manages its own dependencies.

## Flutter Project — Echoed

A complete production-ready Flutter 3.24+ project lives in the `echoed/` folder. Open this
in Android Studio or VS Code with the Flutter extension to run it.

### Key Flutter files
- `echoed/pubspec.yaml` — dependencies (Riverpod 2, GoRouter, Supabase, RevenueCat, just_audio)
- `echoed/lib/main.dart` — app entry point
- `echoed/lib/app.dart` — GoRouter + MaterialApp wiring
- `echoed/lib/core/` — theme, colors, text styles, constants
- `echoed/lib/services/tone_generator.dart` — PCG32 PRNG + logarithmic frequency generation
- `echoed/lib/services/audio_service.dart` — on-device WAV synthesis + playback
- `echoed/lib/services/scoring_service.dart` — cents-based scoring algorithm
- `echoed/supabase/schema.sql` — full PostgreSQL schema + RLS policies
- `echoed/supabase/functions/` — Deno Edge Functions (submit-result, daily seed, RevenueCat webhook)

### Setup steps
1. `cd echoed && flutter pub get`
2. Fill credentials in `lib/core/constants.dart` (Supabase + RevenueCat)
3. Run `supabase/schema.sql` in your Supabase project
4. Deploy edge functions via Supabase CLI
5. Add SpaceMono font TTF files to `assets/fonts/`
6. `flutter run`

## Stack

- **Monorepo tool**: pnpm workspaces
- **Node.js version**: 24
- **Package manager**: pnpm
- **TypeScript version**: 5.9
- **API framework**: Express 5
- **Database**: PostgreSQL + Drizzle ORM
- **Validation**: Zod (`zod/v4`), `drizzle-zod`
- **API codegen**: Orval (from OpenAPI spec)
- **Build**: esbuild (CJS bundle)

## Key Commands

- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- `pnpm --filter @workspace/api-server run dev` — run API server locally

See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details.
