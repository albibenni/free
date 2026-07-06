# Architecture Patterns: Debouncer vs Event-Driven

This document explains two state-management patterns used in this codebase, why each was chosen, and when to prefer one over the other. Written as a reference for the accompanying video.

---

## The Problem They Both Solve

Components in an app need to react to state changes. The naive approach is a **direct method call**:

```swift
// Every time any of these properties changes, call checkSchedules() immediately
calendarImportFocusTitleRules.didSet  → checkSchedules()
calendarImportBreakTitleRules.didSet  → checkSchedules()
calendarImportedScheduleRuleSetId.didSet → checkSchedules()
schedules.didSet                      → checkSchedules()
calendarIntegrationEnabled.didSet     → checkSchedules()
calendarImportsBlockTime.didSet       → checkSchedules()
calendarProvider.objectWillChange     → checkSchedules()
```

This works, but has a hidden problem: if you change 3 calendar properties in a row, `checkSchedules()` runs 3 times — doing the same expensive computation 3 times in a row, when only the last result matters.

Both patterns below solve this, but in different ways and at different levels of abstraction.

---

## Pattern 1: Debouncer

### What it is

A debouncer collapses multiple rapid calls into a single delayed execution. It says:

> "When I receive a signal, wait a short time. If more signals arrive during that wait, reset the timer. Only fire when things go quiet."

### How it works in this codebase

```
calendarImportFocusTitleRules.didSet ──┐
calendarImportBreakTitleRules.didSet ──┤
schedules.didSet ───────────────────────┤──► restart debounce Task
calendarIntegrationEnabled.didSet ─────┤         │
calendarProvider.objectWillChange ─────┘    debounce(100ms)
                                                  │
                                                  ▼
                                        performCheckSchedules() — fires once
```

Implementation:

```swift
// In AppState
private var scheduleCheckDebounceTask: Task<Void, Never>?

// Public API — unchanged for all callers:
func checkSchedules() {
    rescheduleScheduleTimer?()
    scheduleCheckDebounceTask?.cancel()          // restart the window
    scheduleCheckDebounceTask = Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(100))
        guard !Task.isCancelled else { return }
        self?.performCheckSchedules()
    }
}

// The actual work — now only runs once per burst:
private func performCheckSchedules() {
    synchronizeImportedCalendarSchedulesIfNeeded()
    reassertPersistedSessionFlags()
    let updated = logicFacade.checkSession(...)
    applySessionState(updated)
}
```

(In `isTesting` mode `checkSchedules()` calls `performCheckSchedules()` synchronously so tests stay deterministic.)

### What changed vs the old code

| Before | After |
|--------|-------|
| `checkSchedules()` ran the full logic immediately, every call | `checkSchedules()` just sends a signal |
| 3 property changes = 3 full evaluations | 3 property changes = 1 evaluation after 100ms |
| Synchronous | Async (deferred ~100 ms on the main actor) |
| No machinery | One cancel-and-restart `Task` |

### When to use a debouncer

- The problem is purely about **frequency**, not architecture
- All callers trigger the **same outcome**
- The component responsible for the work is already centralized
- You want minimal code change with immediate impact

### When NOT to use a debouncer

- Different callers need different reactions
- You need to know *what* changed, not just *that* something changed
- The components involved don't know about each other yet

---

## Pattern 2: Event-Driven

### What it is

Instead of one component calling a method on another directly, the producer **emits a named event** and the consumer **handles it**. The producer doesn't know (or care) who is listening.

```
BEFORE (direct callback):

BrowserMonitor ──setTrustedState(true)──► AppState.isTrusted = true
                                          (tightly coupled to AppState)

AFTER (event-driven):

BrowserMonitor ──emit(.trustedStateChanged(true))──► handler: switch event { ... }
                                                      (decoupled from AppState)
```

### How it works in this codebase

```swift
// BrowserMonitor defines what it can emit:
class BrowserMonitor {
    enum Event {
        case trustedStateChanged(Bool)
        // Future events go here — no new closure properties needed:
        // case blockedURLVisited(String)
        // case redirectFailed
        // case permissionsRevoked
    }

    private let onEvent: (Event) -> Void

    func checkPermissions(prompt: Bool) {
        let trusted = automator.checkPermissions(prompt: prompt)
        DispatchQueue.main.async { [weak self] in
            self?.onEvent(.trustedStateChanged(trusted))  // emit event
        }
    }
}

// AppState handles all events in one place:
onMonitorEvent: { [weak self] event in
    switch event {
    case .trustedStateChanged(let trusted):
        self?.isTrusted = trusted
    }
}
```

### What changed vs the old code

| Before | After |
|--------|-------|
| `setTrustedState: (Bool) -> Void` closure | `onEvent: (BrowserMonitor.Event) -> Void` closure |
| Adding a new feedback = adding a new closure parameter | Adding a new feedback = adding a new enum case |
| Caller must know the exact type `(Bool) -> Void` | Caller handles a typed domain event |
| N callbacks for N concerns | 1 handler for all concerns |

### When to use event-driven

- A component sits at a **real boundary** and produces multiple distinct outcomes
- You want to add more event types in the future without changing the interface
- The producer and consumer are in different layers (e.g. monitor → state)
- You want a single handler location that's easy to audit

### When NOT to use event-driven

- There's only one event and one consumer — adds ceremony for no gain
- The producer and consumer are tightly coupled by design (e.g. a view and its view model)
- The "events" are really just "trigger this same thing" — use a debouncer instead

---

## Side-by-Side Comparison

| | Debouncer | Event-Driven |
|---|---|---|
| **Core idea** | Collapse many calls into one | Decouple producer from consumer |
| **Problem solved** | Frequency / performance | Communication / coupling |
| **Producer knows consumer?** | Yes (still calls same method) | No (emits to a handler) |
| **Scales to new triggers?** | Yes, just call `checkSchedules()` | Yes, just emit a new event |
| **Scales to new reactions?** | No — all triggers do the same thing | Yes — switch on event type |
| **Code change size** | Small | Medium |
| **Mental model** | Timer / gate | Message bus |

---

## In This Codebase: Why Each Where

### `checkSchedules()` → Debouncer

`AppState` is a **centralized state container** — its job is to own all state. Every trigger for `checkSchedules()` ends up doing the same thing: re-evaluate the session. There's no need for different reactions to different triggers. The problem was purely that it ran too often. A debouncer solved the actual problem with minimal change.

### `BrowserMonitor` → Event-Driven

`BrowserMonitor` is a **boundary component** — it sits between the OS (Accessibility, AppleScript) and the app's state. It already communicates *back* to the app through callbacks, and that list of callbacks will grow as the monitor becomes more capable. Replacing `N` typed closures with `1` event handler makes the interface future-proof and easier to read.

---

## Key Insight

> Use a debouncer when the problem is **timing**.
> Use event-driven when the problem is **communication**.

They are complementary, not competing. You can (and should) use both in the same codebase when each fits its context.
