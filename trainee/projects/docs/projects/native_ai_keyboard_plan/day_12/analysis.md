# Day 12 Analysis: iOS Replace Flow & Preview Accept/Cancel

## Objective

Reach **parity with Android Day 07**: after AI response, show **preview** UI with **Accept** / **Cancel**; handle **selected text** replacement vs whole-field policy (same rules as Android). Polish animations so IME does not dismiss.

## Architecture & Packages

- **Preview:** `UIStackView` or small modal child view inside `inputView` bounds.
- **Input:** Use `textDocumentProxy` to read selection and apply replacements.

### Backend Endpoints

- **Used:** `POST .../functions/v1/transform` only.

## Tasks

1. Implement preview strip + buttons; wire Accept to `textDocumentProxy` insert/replace APIs.
2. Cancel restores prior snapshot (keep in-memory copy before call).
3. Edge case: host app rejects change — show error toast.
4. Screenshot evidence for PR / mentor review.
5. Diff checklist vs Android Day 07 behavior.

## UI / Client Focus

- Accept/Cancel touch targets ≥ 44pt.

## Checklist

- [ ] Preview + accept + cancel flows covered by manual test script
- [ ] Selection replace works in Notes / Messages test
- [ ] Parity notes documented

## Related

- Day 07 Android · [README.md](../README.md)
