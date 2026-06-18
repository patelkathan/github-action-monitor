# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-06-18

### Added
- Menu bar dashboard of monitored GitHub repositories' workflow runs, with search and status filters.
- Auto-detection of recently pushed repositories, with manual star/pin support.
- GitHub Device Flow sign-in.
- Desktop notifications on pipeline completion (optionally scoped to starred repos).
- Re-run failed workflow runs from the menu.
- Launch-at-login and configurable refresh interval settings.
- `os.Logger`-based structured logging (`Sources/Logging.swift`).
- Rate-limit detection and user-visible fetch error banner.
- Bounded GitHub OAuth device-flow polling (stops at code expiry instead of polling forever).
- SwiftPM-based build (`Package.swift`), `Makefile`, signing/notarization script (`scripts/package.sh`), and programmatic app icon generator (`scripts/make-icon.swift`).
- GitHub Actions CI workflow building debug and release configurations.

### Fixed
- Race condition allowing concurrent `fetchRuns()` calls to both pass the in-flight guard.
- Config file writes are now atomic.
