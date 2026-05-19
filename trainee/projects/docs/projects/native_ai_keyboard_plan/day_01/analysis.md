# Day 01 Analysis: Repo, Documentation & Supabase Scaffold

## Objective

Establish the **monorepo layout** under `trainee/projects/native_ai_keyboard/`, finalize **plan documentation** in this folder, and create a **Supabase project** with **Edge Function** stub (`health` or `transform` echo) so Day 02 can add Gemini + prompts.

> Full product intent: [README.md](../README.md) · [spec/overview.md](../spec/overview.md)

## Architecture & Packages

- **Backend:** **Supabase** — Postgres + Edge Functions (Deno/TypeScript). Repo folder e.g. `native_ai_keyboard/supabase/` (migrations + `functions/`).
- **Secrets:** `GEMINI_API_KEY` set only in Supabase Dashboard (Edge Secrets), not committed.
- **Docs:** `native_ai_keyboard_plan/spec/*`, daily `day_XX/analysis.md`.

### Backend Endpoints

- **Implemented today (optional):** `GET` or `POST` health-style Edge Function returning JSON `ok`.
- **Not yet:** `register-device`, `transform` — see [spec/api_endpoints.md](../spec/api_endpoints.md).

## Tasks

1. **Repo / folders:** `supabase/` (CLI layout), `android-keyboard/`, `ios-keyboard/` placeholders with README.
2. **Supabase:** `supabase init`; link project; SQL migration for `devices` table (`device_id`, `platform`, `device_token`, `created_at`).
3. **Edge Function:** minimal `health` or `hello` deployed with `supabase functions serve` / deploy pipeline documented.
4. **Docs:** Ensure [spec/roadmap.md](../spec/roadmap.md) matches Supabase backend wording.
5. **Local dev:** Document `supabase start` (optional Docker) or remote dev project.

## UI / Client Focus

- None (keyboard UI starts Day 04 Android).

## Checklist

- [ ] Supabase project created; `supabase/` linked
- [ ] `devices` migration applied (empty table OK)
- [ ] At least one Edge Function deployable locally or to cloud
- [ ] `GEMINI_API_KEY` **not** in git; placeholder in docs only

## Related

- [README.md](../README.md) · [spec/architecture.md](../spec/architecture.md) · [spec/api_endpoints.md](../spec/api_endpoints.md)
