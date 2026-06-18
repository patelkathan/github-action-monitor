# Contributing to TrayFlow

## Setup

```bash
git clone <repo-url>
cd github-action-monitor
make run
```

This builds via SwiftPM, ad-hoc signs, and launches the app.

## Project layout

- `Sources/` — all Swift source (SwiftPM executable target `TrayFlow`)
- `scripts/make-icon.swift` — generates `Resources/AppIcon.icns`
- `scripts/package.sh` — assembles, signs, and (optionally) notarizes `TrayFlow.app`
- `Makefile` — `build`, `release`, `bundle`, `run`, `icon`, `clean`

## Conventions

- No third-party dependencies — keep `Package.swift` dependency-free unless there's a strong reason.
- Network/auth/config side effects go through `GitHubService`, `ConfigManager`, and `KeychainHelper` respectively — don't reach into `URLSession` or the Keychain from views.
- Use `Log.<category>` (see `Sources/Logging.swift`) instead of `print()`. Never log token values.
- UI state mutations that originate off the main actor must be marshalled via `await MainActor.run { ... }`.
- Keep `@Published` state changes on `GitHubService`/`ConfigManager` minimal and additive — views observe these directly.

## Before submitting a change

```bash
swift build -c release
make bundle
open TrayFlow.app   # sanity check the menu bar item and core flows
```

There is currently no automated test suite — manually verify sign-in, refresh, starring, and re-run behavior for any change touching `GitHubService` or `ConfigManager`.
