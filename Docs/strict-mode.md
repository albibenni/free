# Strict Mode

Strict Mode is a feature in Free that prevents you from stopping or modifying a Focus session once it has started. It is designed for users who want a hard commitment to staying focused — removing the temptation to simply turn off blocking when willpower runs low.

## What It Does

When Strict Mode is enabled and a Focus session is active:

- You **cannot stop** the Focus session from within the app.
- You **cannot change** any blocking settings (browser blocking, allowed websites, etc.) without entering a challenge phrase.
- The **Strict Mode toggle itself** is hidden — it cannot be turned off while blocking is active.

To make any of these changes, you must pass a **challenge phrase** — a short typing exercise that slows down impulsive decisions.

## Enabling Strict Mode

1. Open **Free** and go to **Settings**.
2. Toggle on **Strict Mode**.

Strict Mode takes effect the next time a Focus session starts (or immediately if one is already running).

## Disabling Strict Mode

If no Focus session is active, you can turn off Strict Mode by toggling it off in Settings.

If a Focus session **is** active and Strict Mode is locked:

1. Click **Disable…** in the Strict Mode section.
2. Complete the challenge phrase to confirm.

This is intentionally inconvenient — it gives you a moment to reconsider before abandoning your focus session.

## Why Use It?

Strict Mode is for situations where you know you are likely to give up too easily. It works best when:

- You have a deadline and cannot afford distractions.
- You find yourself stopping Focus sessions early out of habit.
- You want scheduled blocks to be truly uninterruptible.

## Tamper Resistance and Honest Limits

Strict Mode is a **commitment device, not a security boundary**. What it does defend:

- **Quitting the app:** `applicationShouldTerminate` reads *in-memory* session state (wired from `AppState` via providers), so editing the persisted flags from a terminal does not unlock the quit path.
- **External `defaults write` tampering:** persisted `IsStrict`/`IsBlocking` flags are re-asserted from in-memory state on every browser-monitor snapshot and schedule tick — an external edit is repaired, not honored.
- **Pasting the challenge phrase:** the challenge field suppresses paste; the phrase must be typed.
- **Impulse stops:** a 10-second grace period after starting a pomodoro focus phase locks skip/stop.

What it deliberately does **not** defend:

- `kill -9` (or Activity Monitor force-quit) terminates the process; blocking stops until relaunch. Surviving that requires a privileged helper daemon, which Free does not ship.
- Editing persisted flags **while the app is not running** changes what the next launch restores.
- The challenge phrase is a fixed, visible sentence — friction by design, not authentication.

## Tips

- Enable Strict Mode **before** a session you know will be challenging.
- Use [Schedules](../Sources/Free/UI/Sections/Schedules/) to automate Focus sessions so you don't have to manually start them.
- Combine with the Pomodoro timer for structured work/break cycles that Strict Mode will protect.
