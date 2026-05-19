# Day 13 Analysis: Settings Persistence & Cross-Platform QA

## Objective

Persist **default mode**, **theme**, and **locale** across keyboard relaunch: Android `SharedPreferences`, iOS App Group **UserDefaults**. Optionally sync to **Supabase Postgres** (`device_settings`) via Edge Function if product chooses server-side settings. Run **cross-platform QA**: empty text, max length, offline, timeout, wrong token, **local rate debounce** + optional **429** from Edge.

## Architecture & Packages

- **Backend:** Optional Edge Function `settings` + table per [spec/architecture.md](../spec/architecture.md); otherwise device-only.
- **Clients:** sync on launch and after change; debounce writes; **local** min-interval between transform calls.

### Backend Endpoints

- **Used (regression):** `POST .../functions/v1/transform`; optional `GET/PUT` settings Edge routes per [spec/api_endpoints.md](../spec/api_endpoints.md).

## Tasks

1. If server settings: wire Edge Function to `device_settings` keyed by `device_id` / token.
2. Android: read/write prefs + optional sync from Supabase.
3. iOS: App Group suite; migrate local-only keys if any.
4. QA matrix spreadsheet: 10 rows min (both platforms) including **429** and offline.
5. Fix P0/P1 bugs found; defer P2 with tickets.

## UI / Client Focus

- Minimal settings UI can live in keyboard overflow menu or companion stub activity.

## Checklist

- [ ] Settings survive process kill on both OSes
- [ ] Server settings round-trip (if enabled)
- [ ] QA matrix attached to PR or wiki

## Related

- [spec/api_endpoints.md](../spec/api_endpoints.md) · [spec/architecture.md](../spec/architecture.md)
