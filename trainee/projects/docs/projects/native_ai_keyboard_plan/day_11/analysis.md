# Day 11 Analysis: iOS Modes, Themes & Long-Press Parity

## Objective

Implement **four modes** with persisted selection (App Group or extension `UserDefaults` with suite), **light/dark/system** keyboard appearance, and **long-press** alternate characters matching Android Day 06 behavior as closely as iOS APIs allow.

## Architecture & Packages

- **State:** `UserDefaults(suiteName:)` if container configured; else extension defaults until Day 13.
- **Haptics:** light impact on mode change (optional).

### Backend Endpoints

- **Used:** `POST .../functions/v1/transform` with `mode` + `theme` fields.

## Tasks

1. Mode control: `UISegmentedControl` replacement with scrollable chips if needed.
2. Theme: respond to `traitCollection` + manual override toggle.
3. Long-press: key `UIControl` events with alternate popup.
4. i18n: `Localizable.strings` for action labels TR/en.
5. Cross-check prompt behavior vs Android for same input (manual matrix).

## UI / Client Focus

- Selected mode high contrast in both interface styles.

## Checklist

- [ ] Mode + theme sent on each transform request
- [ ] Long-press alternates work for agreed key set
- [ ] Strings localized TR/en

## Related

- Day 06 Android · [spec/ui_design.md](../spec/ui_design.md)
