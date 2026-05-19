# Day 10 Analysis: iOS AI Bar & Transform API

## Objective

Enable **Full Access** test path and integrate **`POST .../functions/v1/transform`** (Supabase Edge) via `URLSession`: same JSON contract as Android. Loading/error UI parity with Day 05. Store bearer token in **Keychain** or `UserDefaults` (MVP).

## Architecture & Packages

- **Networking:** async/await `URLSession`; codable DTOs matching Edge Function JSON.
- **Security:** TLS only; pin optional post-MVP.

### Backend Endpoints

- **Used:** `POST .../functions/v1/transform`, optionally `POST .../functions/v1/register-device`.

## Tasks

1. Request Open Access in UI test instructions; verify outbound call succeeds.
2. Map same error codes as Android to user strings (Localizable.strings TR/en).
3. Hook four actions to API; default mode Work until Day 11.
4. Cancel in-flight task when user switches action quickly.
5. Telemetry: simple `os_log` for latency in debug.

## UI / Client Focus

- Disable actions when `documentContextBeforeInput` + selection empty.

## Checklist

- [ ] Successful transform on device/simulator with Full Access
- [ ] Error states human-readable
- [ ] No keychain secrets in git

## Related

- [spec/api_endpoints.md](../spec/api_endpoints.md) · Day 05 Android parity
