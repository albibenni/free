# Build, Test, and Release

Everything targets **macOS 26.0** and compiles in **Swift 6 language mode**. The deployment target is declared in four places that must stay in sync: `Package.swift`, `build.sh`, `package.sh`, and `Resources/Info.plist` (`LSMinimumSystemVersion`).

## Build paths

There are two ways to build the app, sharing one entry point (`FreeAppEntry.run()`):

| Command | What it produces | Use it for |
|---|---|---|
| `./build.sh` | `Free.app` (debug, raw `swiftc`, arm64) | Local run: `open Free.app` |
| `./package.sh` | `Free.dmg` (release, signed) | Distribution |
| `swift build` / `swift run FreeApp` | SPM library + bare executable | CI smoke builds, quick iteration |
| `make app` / `make dmg` | Aliases for the two scripts | — |

The SPM `FreeLogic` target contains the whole app; `@main` is compiled only outside SwiftPM (`#if !SWIFT_PACKAGE`), and the thin `FreeApp` executable target exists so `swift build` exercises the real entry point.

## Signing and notarization

`package.sh` always signs with **Hardened Runtime** and the entitlements in `Resources/Free.entitlements` (which grants `com.apple.security.automation.apple-events` — without it, Hardened Runtime would block the app's own AppleScript browser control).

- **Default (no env vars):** ad-hoc signature. Good for local installs; TCC grants (Accessibility/Automation/Calendar) survive rebuilds.
- **`CODESIGN_IDENTITY="Developer ID Application: …"`:** real signature for distribution.
- **`NOTARY_PROFILE=<notarytool keychain profile>`** (with a real identity): the DMG is submitted to Apple notarization and stapled.

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="free-notary" \
./package.sh
```

Set up the notary profile once with `xcrun notarytool store-credentials free-notary`.

To avoid exporting env vars every release, create a gitignored `release.env` in the repo root — `package.sh` sources it automatically:

```bash
# release.env (gitignored)
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="free-notary"
```

The app is **arm64-only** by design — macOS 26 runs on effectively no Intel hardware.

## Tests

```bash
swift test            # or: make test
make coverage         # coverage run + report (FREE_COVERAGE_MODE=1)
make coverage-gates   # coverage + regional gates
```

- ~720 tests, Swift Testing framework, no XCTest dependency. Under `swift test` the suite runs in SwiftPM's `swiftpm-testing-helper` process; production code detects test runs through `TestProcessDetector` (see `Docs/full-app.md`, Testing Strategy).
- Gates: **95%** total lines (CI), **93%** regional on `Logic/State/Services/`, **92%** regional on `UI/`. These are honest measurements with small headroom — if a change drops below them, coverage genuinely regressed.

## Git hooks

```bash
make hooks   # once per clone
```

Points `core.hooksPath` at `scripts/githooks/`; the pre-commit hook runs `scripts/validate.sh` (build + tests).

## CI

`.github/workflows/ci.yml` runs on pushes to `main` and PRs:

1. **test-and-coverage** — selects the newest installed Xcode (required for the macOS 26 target), builds via SPM, runs `make coverage`, and enforces the 95% line gate.
2. **package-dmg** — builds the release DMG via `make package` and uploads it as an artifact.
