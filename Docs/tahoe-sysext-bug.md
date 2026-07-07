# macOS Tahoe (26.x) — system extension won't activate

**Status:** BLOCKED by an Apple OS bug, not our code. Last verified failing on
**macOS 26.5.2 (build 25F84)**, Apple Silicon, on 2026-07-06.

The v2 content-filter **system extension** (`com.benni.Free.ContentFilter`) cannot
be activated by `OSSystemExtensionRequest` on this machine. The app, the extension
bundle, signing, and notarization are all correct — a stock Apple-pattern control
extension fails the same way. This is a Tahoe `sysextd` regression affecting *new*
Developer-ID system extensions.

## Exact failure signature

App side (`OSSystemExtensionRequestDelegate.didFailWithError`):

```
System extension activation failed: Extension not found in App bundle.
Unable to find any matched extension with identifier: com.benni.Free.ContentFilter
```
(`OSSystemExtensionErrorDomain` code **4** = `extensionNotFound`.)

`sysextd` side (the real tell — `log show --predicate 'process == "sysextd"'`):

```
sysextd: attempting to realize extension with identifier com.benni.Free.ContentFilter
sysextd: no policy, cannot allow apps outside /Applications
```

…even though the host app is verifiably in `/Applications` (`open`ed from
`/Applications/Free.app`, exec path confirmed via `lsof`, no App Translocation,
no quarantine, single LaunchServices registration). `systemextensionsctl list`
stays at `0 extension(s)`.

## Why we're sure it's the OS, not us (ruled out on 2026-07-06)

- **Notarization** — build is notarized + stapled, `spctl` accepts it. (An earlier
  bug: `scripts/run-v2.sh` installs an *unnotarized Debug* build — never use it
  while SIP is on. Use `scripts/package-v2.sh`.)
- **Bundle correctness** — right identifier, `SYSX` package type,
  `content-filter-provider-systemextension` entitlement, hardened runtime, valid
  `Free CF DevID` profile, matching Team `YVZG5QKT42`, embedded at
  `Contents/Library/SystemExtensions/…`.
- **Duplicate registrations / bundle-ID collision** — removed. A stray
  `~/benni-projects/Freee/Freee.app` also declared `com.benni.Free` and was moved
  to `Freee.app.collision-bak`.
- **Stale daemon / cache** — reproduced on a *fresh* `sysextd` after reboot.
- **MDM / config profile** — none installed; machine is unmanaged (so "no policy"
  is expected and normal, not the blocker).
- **Clean-room control** — a minimal Apple-pattern content filter (bare
  `OSSystemExtensionRequest` + trivial `NEFilterDataProvider`, no FreeLogic) built
  with the *same* IDs/profiles/signing/notarization fails **identically**. The
  probe project is not committed; regenerate with the recipe in the session notes
  if needed.

## Corroboration (other projects, same OS bug)

- Objective-See **LuLu** — same `NEFilterDataProvider` + Developer-ID model; the
  network extension never attaches on Tahoe. github.com/objective-see/LuLu
  issues **#784**, **#825**.
- **Tailscale** #17891 — Tahoe system-extension breakage.
- Apple Developer Forums — "Extension not found in App bundle":
  https://developer.apple.com/forums/thread/690609

Pattern reported across projects: **only *new* activations fail**; system
extensions activated *before* upgrading to macOS 26 keep working.

## Re-test after every macOS update

Apple tends to fix `sysextd` regressions in point releases. After updating macOS:

1. `sw_vers` — note the new build; check `softwareupdate -l` first.
2. Make sure the real (not probe) app is installed:
   `./scripts/package-v2.sh` (notarized) — never `run-v2.sh` with SIP on.
3. Run the helper: **`./scripts/retest-sysext.sh`**
   - It launches the app, waits, and reports **FIXED** (extension realized /
     approval prompt / `systemextensionsctl list` non-empty) or **STILL BROKEN**
     (the `cannot allow apps outside /Applications` signature).
4. If it prompts for approval: System Settings → General → Login Items &
   Extensions → Network Extensions → allow **Free**.

## Meanwhile — confirm the app is shippable on a healthy Mac

The notarized build is almost certainly fine for end users; only *this* dev
machine's Tahoe `sysextd` is broken. A ready-to-transfer, stapled build is at:

```
build/dist/Free-v2-notarized.zip
```

On another Mac (ideally not on the exact broken 26.x build): unzip → move
`Free.app` to `/Applications` → launch → start a focus session → approve the
extension. If it activates there, the app is correct and we're purely waiting on
Apple.

## Long-shot local workarounds (unproven for this specific error)

- Correct SIP-off sequence (order matters — `reset` wipes the developer flag):
  Recovery → `csrutil disable` → reboot → `systemextensionsctl reset` → reboot →
  `systemextensionsctl developer on` → relaunch. Re-enable SIP (`csrutil enable`)
  after.
- Some reports: uninstall → reboot →
  `sudo security authorizationdb write com.apple.system-extensions.admin authenticate-admin-nonshared`
  → reboot → reinstall.
