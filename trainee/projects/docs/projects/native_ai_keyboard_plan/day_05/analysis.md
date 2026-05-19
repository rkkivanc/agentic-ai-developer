# Day 05 Analysis: Android AI Action Bar & Transform API

## Objective

Wire the four **AI actions** to **`POST .../functions/v1/transform`** (Supabase Edge): show **loading** and **error** states (toast or inline), send `text`, `mode` (default Work), `action`, `locale`, optional `theme`. Implement **local debounce** (min seconds between calls) in `SharedPreferences`. Insert successful `result` into field **or** hold for preview flow on Day 07.

## Architecture & Packages

- **Networking:** Retrofit + OkHttp; base URL = `https://<PROJECT_REF>.supabase.co/functions/v1/` from `BuildConfig`.
- **Auth:** Attach `Authorization: Bearer` after `register-device` (Day 03).

### Backend Endpoints

- **Used:** `POST .../functions/v1/transform` (required).
- **Optional:** `POST .../functions/v1/register-device` if not completed Day 03.

## Tasks

1. Implement Retrofit interface matching [spec/api_endpoints.md](../spec/api_endpoints.md).
2. On action tap: read current field text / selection; call API on background thread; cancel on new tap.
3. Handle `401`, `429`, `502`, `504` with user-readable messages (Turkish + English strings in resources).
4. Ensure **network permission** and cleartext policy only for debug if needed.
5. Log latency in debug builds only.

## UI / Client Focus

- Action bar: Correct, Rewrite, Shorten, Expand — enabled/disabled when text empty.

## Checklist

- [ ] Each action reaches **Supabase Edge** and returns transformed text in happy path
- [ ] Loading indicator visible during request
- [ ] Errors surfaced without crashing IME
- [ ] Empty text disables actions or shows hint

## Related

- [spec/api_endpoints.md](../spec/api_endpoints.md) · Day 03 transform service
