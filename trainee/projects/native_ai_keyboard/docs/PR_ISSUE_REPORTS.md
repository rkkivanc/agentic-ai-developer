# GitHub PR copy — Native AI Keyboard (issue reports)

**Title**

```
Project - Native AI Keyboard -> Issue Reports, iOS Report Sheet UX, and Edge submit-issue-report
```

Paste everything below into the PR description field.

---

## Summary

This PR adds **Report a problem** to the Native AI Keyboard host app (`trainee/projects/native_ai_keyboard/`): feedback is stored in Supabase (`public.issue_reports`) via a new Edge function. Optional owner email uses Resend when project secrets are set. The iOS sheet uses TR/EN copy, a clear daily-limit state, and user-safe errors (no raw gateway JSON). Hosted deploy notes, smoke scripts, and an open issue for Resend delivery are included.

**Scope note:** Builds on the existing MVP (`register-device`, `transform`, App Group Supabase config). This branch only adds the issue-report path.

---

## 📋 PR Description

This PR introduces **in-app issue reporting** for Native AI Keyboard: users can send feedback from the host app; reports persist on Supabase and can trigger an optional Resend notification to the project owner.

**Key improvements**

- **Supabase / database:** New `issue_reports` migration; RLS enabled with no client policies (inserts only via Edge service role).
- **Edge function:** `submit-issue-report` — validates the same device Bearer token as `transform`, enforces one report per device per UTC day (dev bypass secret available), inserts metadata (app version, OS, locale), then calls Resend when `RESEND_API_KEY` + `REPORT_TO_EMAIL` are set. Returns HTTP 201 even if mail fails (`mailSent` / `mailDetail` in JSON).
- **iOS host UX:** `FeedbackReporter` + `ReportProblemSheet` — vertical text field, **locked card** when the local daily cap is reached (avoids a disabled field that blocks the keyboard), TR/EN strings via `IssueReportL10n`, classified errors for 404 / missing table / 429.
- **Dev & QA:** `smoke-submit-issue-report.sh`, `dev-issue-report-test-hints.sh`, plist bypass `AIKeyboardIssueReportBypassDailyLimit`, Edge secret `ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT` for same-day retesting.
- **Documentation:** `docs/OPEN_ISSUES.md` tracks Resend inbox delivery (DB insert works; email still open). README checklists updated (English).

**Known limitation**

- Resend may not deliver to `REPORT_TO_EMAIL` when using the default sandbox sender — see [`docs/OPEN_ISSUES.md`](./OPEN_ISSUES.md).

---

## ✅ Checklist

- [ ] Code follows the project standards and guidelines.
- [ ] Relevant documentation is updated (`supabase/README.md`, `ios-keyboard/README.md`, `docs/OPEN_ISSUES.md`).
- [ ] No secrets committed (`.env.example` only; real keys in Supabase Edge secrets).
- [ ] Dev-only flags documented (`AIKeyboardIssueReportBypassDailyLimit`, `ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT`) and disabled before production.
- [ ] The PR has been reviewed by at least one team member before merging.

---

## 🛠 Steps to test

### Supabase (hosted)

1. From `trainee/projects/native_ai_keyboard`: `supabase db push` and `supabase functions deploy submit-issue-report`.
2. Optional mail: `supabase secrets set RESEND_API_KEY=re_... REPORT_TO_EMAIL=you@example.com`
3. Set `SUPABASE_FUNCTIONS_BASE=https://<project-ref>.supabase.co/functions/v1` and run:
   ```bash
   ./supabase/scripts/smoke-submit-issue-report.sh
   ```
   Expect **201** on first submit, **429** on second (same UTC day) unless bypass secret is `true`.
4. In Dashboard → SQL, confirm rows in `public.issue_reports`.

### iOS

1. If `project.yml` changed: `cd ios-keyboard && xcodegen generate`, open `AIKeyboard.xcodeproj`.
2. Set `SupabaseProjectURL` to `https://<project-ref>.supabase.co` (no `/functions/v1`); open host app once (App Group sync).
3. **Settings → Report a problem** — enter ≥10 characters, submit → success message; row appears in DB.
4. Submit again the same calendar day → **locked** sheet (title + message, no text field).
5. For same-day retest: `AIKeyboardIssueReportBypassDailyLimit=true` in plist + Edge `ISSUE_REPORT_BYPASS_UTC_RATE_LIMIT=true` (turn both off before release).
6. If email is required: check Resend dashboard logs; if inbox empty, see `docs/OPEN_ISSUES.md`.

---

## Related

- Plan: [`../docs/projects/native_ai_keyboard_plan/`](../docs/projects/native_ai_keyboard_plan/README.md)
- Edge secrets: [`../supabase/functions/README.md`](../supabase/functions/README.md)
