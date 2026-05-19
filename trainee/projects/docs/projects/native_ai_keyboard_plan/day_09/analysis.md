# Day 09 Analysis: iOS Layout — Parity with Android

## Objective

Match **Android Day 04–06 layout zones**: mode row, four action buttons, QWERTY grid. Use **Auto Layout** / `UIStackView`; typography and spacing close to system keyboard. TR/EN label swap for keys where needed.

## Architecture & Packages

- **Views:** Separate small `UIView` subclasses or SwiftUI wrapped in hosting controller if team allows (native spec prefers UIKit stacks per [spec/architecture.md](../spec/architecture.md)).

### Backend Endpoints

- **None** (still offline layout).

## Tasks

1. Implement key grid with touch down/up states.
2. Wire dummy labels for modes/actions matching Android order.
3. Light/dark colors via `traitCollection` / dynamic colors.
4. Snapshot comparison checklist vs Android reference PNG (manual OK).
5. Accessibility: VoiceOver labels on actions.

## UI / Client Focus

- Visual parity with [assets/mockups/keyboard_default_light.png](../assets/mockups/keyboard_default_light.png).

## Checklist

- [ ] Three zones visible and aligned
- [ ] Dark mode readable
- [ ] Rotations / different devices smoke-tested (simulator)

## Related

- [spec/ui_design.md](../spec/ui_design.md)
