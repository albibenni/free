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

## Releases

Pushing a tag like `v1.2.0` triggers `.github/workflows/release.yml`, which builds, signs, notarizes, Gatekeeper-verifies, and publishes the DMG as a GitHub Release (version stamped into `Info.plist` from the tag).

One-time repo secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE` | Developer ID Application cert + key, exported as `.p12`, base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERTIFICATE_PWD` | The password chosen when exporting the `.p12` |
| `CODESIGN_IDENTITY` | `Developer ID Application: Alberto Benatti (YVZG5QKT42)` |
| `NOTARY_APPLE_ID` | Apple ID email for notarization |
| `NOTARY_PASSWORD` | App-specific password (account.apple.com) |
| `NOTARY_TEAM_ID` | `YVZG5QKT42` |

Export the `.p12` from Keychain Access: My Certificates → right-click the "Developer ID Application" certificate → Export (choose a password).

## Homebrew (cask tap)

Free is installable via Homebrew Cask from a personal tap:

```bash
brew install --cask albibenni/free/free
brew upgrade --cask free
```

- **Tap repo:** [`albibenni/homebrew-free`](https://github.com/albibenni/homebrew-free) — a separate repo (a tap *must* be named `homebrew-<name>`) holding one file, `Casks/free.rb`. It's a thin pointer (URL + `sha256`) to the notarized `Free.dmg` published by this repo's releases; it does not host the app.
- **Cask internals:** `url` interpolates the tag (`.../releases/download/v#{version}/Free.dmg`), `depends_on macos: :tahoe` (means "≥ macOS 26"), and a `zap` stanza removes `com.benni.Free` preferences/caches on `brew uninstall --zap`. Validate changes with `brew style --cask free` and `brew audit --cask free`.

### Automated cask bump on release

The `Release` workflow's **Update Homebrew cask** step runs after the GitHub Release is created: it computes the new DMG's `sha256`, rewrites `version` + `sha256` in the tap's `Casks/free.rb`, and pushes. So a normal release (`git tag vX.Y.Z && git push origin vX.Y.Z`) updates Homebrew with no manual step. The step **skips itself** if the token below is absent, so releases never fail because of it.

**One-time setup** — a fine-grained PAT is required because the workflow runs in *this* repo but must push to the *tap* repo (the built-in `GITHUB_TOKEN` can't):

1. Create the tap repo first (the token picker only lists repos that exist).
2. Generate a fine-grained PAT at <https://github.com/settings/personal-access-tokens/new>:
   - **Resource owner:** `albibenni`
   - **Repository access:** Only select repositories → `homebrew-free`
   - **Permissions → Repository → Contents:** Read and write (Metadata: Read is added automatically)
3. Store it as an Actions secret named `HOMEBREW_TAP_TOKEN` on this repo, either:
   - **Web UI:** repo → Settings → Secrets and variables → Actions → New repository secret, or
   - **CLI:** `gh secret set HOMEBREW_TAP_TOKEN --repo albibenni/free`

Fine-grained PATs expire (max ~1 year) — when the bump step starts failing with an auth error, regenerate the token and re-run `gh secret set`.

**Manual bump** (fallback, or before the token is set up): in the tap repo, set `version` and the DMG's `sha256` (`shasum -a 256 Free.dmg`) in `Casks/free.rb`, then commit and push.

Graduating to the official `homebrew/cask` (for the shorter `brew install --cask free`, no tap step) needs the source repo to clear the self-submission notability bar (~90 forks / 90 watchers / 225 stars) or earn an exception; the same cask file is reused.

## Distribution note (why not the Mac App Store)

The App Store requires the App Sandbox, which blocks both of Free's blocking mechanisms: `NSAppleScript` events to browsers and the Accessibility API. Direct distribution of the notarized DMG is the standard channel for this app category. An App Store path exists but means replacing the engine with a Network Extension content filter (`NEFilterDataProvider`) — tracked as a v2 idea in `todo.md`.

## CI

`.github/workflows/ci.yml` runs on pushes to `main` and PRs:

1. **test-and-coverage** — selects the newest installed Xcode (required for the macOS 26 target), builds via SPM, runs `make coverage`, and enforces the 95% line gate.
2. **package-dmg** — builds the release DMG via `make package` and uploads it as an artifact.
