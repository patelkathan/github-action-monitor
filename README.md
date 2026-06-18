# TrayFlow

A lightweight macOS menu bar app that keeps an eye on your GitHub Actions pipelines — at a glance, without opening a browser tab.

## Features

- Live status for your repositories' workflow runs (queued / running / success / failure)
- Auto-detects your recently active repos, or pin specific ones manually
- Star repos to keep them pinned at the top and (optionally) limit notifications to just them
- Desktop notifications when a pipeline finishes
- Re-run a failed workflow run directly from the menu
- Sign in with GitHub Device Flow — no token to copy or manage
- Launch at login, configurable refresh interval (or manual-only)

## Download

Grab the latest `TrayFlow.dmg` from the [Releases page](../../releases), open it, and drag `TrayFlow.app` into `Applications`.

> **Note:** Release builds are ad-hoc signed, not notarized (no Apple Developer account is wired into CI). On first launch, Gatekeeper will say the app "cannot be opened because it is from an unidentified developer." Right-click (or Control-click) `TrayFlow.app` → **Open** → **Open** to confirm — you only need to do this once. To build a notarized version yourself, see [Signing & Notarization](#signing--notarization).

## Installing / Running From Source

Requires macOS 13+ and Xcode (for the Swift toolchain).

```bash
git clone <repo-url>
cd github-action-monitor
make run        # builds, code-signs (ad-hoc), and opens TrayFlow.app
```

Other useful targets:

```bash
make build      # debug build via SwiftPM
make release    # release build via SwiftPM
make bundle     # build + package into TrayFlow.app (no launch)
make dmg        # build + package into TrayFlow.dmg
make icon       # regenerate Resources/AppIcon.icns
make clean      # remove build artifacts
```

## Signing & Notarization

`scripts/package.sh` (invoked by `make bundle`) ad-hoc signs the app by default, which is fine for running on your own Mac. To distribute it to others:

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="your-notary-profile"   # set up via:
# xcrun notarytool store-credentials your-notary-profile \
#   --apple-id you@example.com --team-id TEAMID --password <app-specific-password>

make bundle
```

The same `CODESIGN_IDENTITY` / `NOTARY_PROFILE` env vars can be set as repository secrets and exported in `.github/workflows/release.yml` to produce notarized releases from CI.

## Releasing

Push a version tag and the [release workflow](.github/workflows/release.yml) builds, packages, and attaches `TrayFlow.dmg` to a new GitHub Release automatically:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Authentication

On first launch, sign in with **GitHub Device Flow**: TrayFlow shows a one-time code, you approve it on github.com, and the resulting token is stored in the macOS Keychain (`com.kathanpatel.TrayFlow` service) — never written to disk in plaintext. TrayFlow makes no network calls other than to the GitHub API and sends no telemetry.

The default GitHub CLI OAuth Client ID is used (requests `repo` and `workflow` scopes). If you'd rather authorize via your own GitHub OAuth App (with Device Flow enabled), set a custom Client ID in Settings.

## Configuration

Settings and the monitored-repo list are stored at:

```
~/Library/Application Support/TrayFlow/config.json
```

You can edit monitored repos, refresh interval, notification preferences, and an optional custom OAuth Client ID from the in-app Settings panel (⌘,).

## Architecture

| File | Responsibility |
|---|---|
| `Sources/GitHubService.swift` | GitHub API calls, OAuth device flow, polling/refresh scheduling |
| `Sources/ConfigManager.swift` | Persisted settings & monitored repo list |
| `Sources/KeychainHelper.swift` | Secure token storage |
| `Sources/NotificationManager.swift` | Desktop notifications |
| `Sources/Models.swift` | Codable models for GitHub API responses & app state |
| `Sources/Logging.swift` | `os.Logger` categories |
| `Sources/*View.swift` | SwiftUI menu bar UI |

## License

MIT — see [LICENSE](LICENSE).
