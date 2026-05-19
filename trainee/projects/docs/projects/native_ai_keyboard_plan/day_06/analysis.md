# Day 06 Analysis: Android Modes, Themes & Long-Press Alternates

## Objective

Add **mode strip** (Work / Friends / Family / Flirt) with persisted selection, **light/dark** keyboard chrome using `values-night` or runtime theme, and **long-press** popup for alternate characters (e.g. **i** → **ı**, **ü**, etc.) per Turkish typing expectations.

## Architecture & Packages

- **State:** `SharedPreferences` for `defaultMode`, `theme` (`light|dark|system`).
- **UI:** `ChipGroup` / `RecyclerView` for modes; theme toggles redraw keyboard backgrounds and key caps.

### Backend Endpoints

- **Used:** `POST .../functions/v1/transform` — include selected `mode` and `theme` in body if prompt uses them (Day 02 hooks).

## Tasks

1. Mode strip UI + persistence; pass `mode` into Day 05 API layer.
2. Implement **system** theme follow: read `Configuration.UI_MODE_NIGHT_YES`.
3. Long-press: `PopupWindow` or platform key popup for alternate chars map per key.
4. Align colors with [spec/ui_design.md](../spec/ui_design.md) and reference mockup.
5. Optional: `PUT /settings` sync stub for theme (full sync Day 13).

## UI / Client Focus

- Selected mode clearly highlighted; dark theme parity.

## Checklist

- [ ] All four modes selectable and sent to API
- [ ] Light/dark (and system) visibly change keyboard chrome
- [ ] At least one long-press alternate chain works (document map in code comments)
- [ ] No regression on Day 05 typing + AI calls

## Related

- [spec/ui_design.md](../spec/ui_design.md) · [README.md](../README.md) (MVP features)
