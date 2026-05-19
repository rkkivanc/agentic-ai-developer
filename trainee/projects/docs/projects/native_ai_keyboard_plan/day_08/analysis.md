# Day 08 Analysis: iOS Keyboard Extension Skeleton

## Objective

Add **Keyboard Extension** target in Xcode, implement `KeyboardViewController` lifecycle, and document **Full Access** requirement for outbound HTTPS. Mirror Android structure placeholders: mode strip + action bar + key area (static).

## Architecture & Packages

- **Project:** `ios-keyboard/` — extension + optional container app for settings later.
- **Sharing:** App Group capability placeholder for Day 13 settings.

### Backend Endpoints

- **None** (network disabled until Full Access + Day 10); optional local mock.

## Tasks

1. Create extension scheme; set deployment target iOS 15+ per spec.
2. Basic `UIInputViewController` / `UIInputView` with Auto Layout root stack.
3. Info.plist keys for keyboard and network usage description strings.
4. Verify extension appears in Settings → Keyboards.
5. Document build/run steps in `ios-keyboard/README.md`.

## UI / Client Focus

- Safe area, keyboard height class, placeholder keys non-functional OK.

## Checklist

- [ ] Extension loads without crash when selected
- [ ] Full Access copy drafted in spec or onboarding markdown
- [ ] Folder layout matches [README.md](../README.md)

## Related

- [spec/overview.md](../spec/overview.md) (iOS Full Access) · [spec/ui_design.md](../spec/ui_design.md)
