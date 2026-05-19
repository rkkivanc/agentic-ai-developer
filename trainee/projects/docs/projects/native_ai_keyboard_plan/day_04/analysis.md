# Day 04 Analysis: Android IME Skeleton & QWERTY

## Objective

Create the **Android keyboard module** (`InputMethodService`), show a **QWERTY** key area, and support **TR/EN keyboard language** switch (layout or labels) aligned with host / user preference. No AI network calls yet unless trivial health ping.

## Architecture & Packages

- **Project:** `android-keyboard/` — minSdk per [spec/overview.md](../spec/overview.md) (API 26+).
- **Entry:** `MyInputMethodService` extends `InputMethodService`.
- **Layout:** XML keyboard view or `KeyboardView` / custom key grid.

### Backend Endpoints

- **None required** for UI skeleton (optional `GET /health` check from debug menu).

## Tasks

1. Android Studio module; manifest `service` + `intent-filter` for IME.
2. Inflate keyboard root: placeholder rows for **mode strip** and **action bar** (can be static labels).
3. Implement key events → `InputConnection.commitText` for alphanumeric.
4. **Locale:** resource qualifiers or in-keyboard toggle for TR-specific keys where needed.
5. Document how **Full Access** equivalent on Android (network permission) will be requested before Day 05.

## UI / Client Focus

- QWERTY spacing, key feedback (ripple), baseline light theme.

## Checklist

- [ ] Keyboard selectable in system settings
- [ ] Typing works in any `EditText` in a sample host app
- [ ] TR/EN switch behavior defined and visible
- [ ] Mode/action rows visible (even if non-functional)

## Related

- [spec/ui_design.md](../spec/ui_design.md) · [spec/roadmap.md](../spec/roadmap.md)
