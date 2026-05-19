# Day 07 Analysis: Android Replace Flow, Preview Accept/Cancel & Smoke QA

## Objective

Before replacing host text, show **preview** of AI result with **Accept** and **Cancel**. **Accept** commits via `InputConnection`; **Cancel** discards. Cover **selection replace** when user highlighted text. End day with **Android smoke QA** checklist (offline, timeout, empty).

## Architecture & Packages

- **State machine:** `Idle` → `Loading` → `Preview` → `Committed` | `Cancelled`.
- **UI:** Bottom sheet or inline banner above keyboard for preview (must not break IME window).

### Backend Endpoints

- **Used:** same `POST .../functions/v1/transform` (no second round-trip for MVP accept).

## Tasks

1. On successful response, show preview strip with full proposed text (scroll if long).
2. Accept: replace selection or full field per product rule (document in code).
3. Cancel: close preview, leave original text untouched.
4. QA: airplane mode → error; very long text → truncate or error per API; double-tap action race.
5. Note parity items for **iOS Day 12** in team doc or ticket.

## UI / Client Focus

- Preview legible in light/dark; primary/secondary buttons for Accept/Cancel.

## Checklist

- [ ] Preview shown for every successful transform
- [ ] Accept writes correct text to host app
- [ ] Cancel restores prior state
- [ ] Smoke scenarios documented with pass/fail

## Related

- [README.md](../README.md) (preview feature) · [spec/roadmap.md](../spec/roadmap.md)
