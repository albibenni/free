# Free — Diagrams

> Visual reference for the app's architecture, data flows, and state machines.

---

## 1. High-Level Architecture

```mermaid
flowchart TB
  subgraph UI["AppKit UI (108 files)"]
    Shell["Shell + Sidebar + Status Item"]
    Focus["Focus Section"]
    RulesUI["Allowed Websites"]
    SchedulesUI["Schedules"]
    PomodoroUI["Pomodoro"]
    CalendarUI["Calendar"]
    SettingsUI["Settings"]
  end

  subgraph State["State Core"]
    AppState["AppState\n(@Observable source of truth)"]
    ReadModel["Read Model\n(derived state)"]
    Facade["AppStateLogicFacade\n(dispatch router)"]
    Persist["PersistenceCoordinator\n(observation → UserDefaults)"]
    Bootstrap["BootstrapService\n(load on launch)"]
    Store["SettingsStore\n(UserDefaults)"]
  end

  subgraph Domain["Domain Coordinators + Services"]
    SessionC["Session Coordinator"]
    SchedC["Schedule Coordinator\n+ ScheduleCheck Coordinator"]
    FocusC["FocusFlow Coordinator\n(pomodoro + pause)"]
    RulesC["RuleSet Coordinator"]
    BlockingC["Blocking Coordinator"]
    ScheduleEngine["ScheduleEngine\n(stateless)"]
    PomodoroEngine["PomodoroEngine\n(stateless)"]
    PauseEngine["PauseEngine\n(stateless)"]
    RuleSetSvc["RuleSetService\n(resolve active rules)"]
    CalendarSvc["CalendarImport/SyncService"]
  end

  subgraph Enforcement["Blocking Enforcement (background thread)"]
    Monitor["BrowserMonitor\n(1.5s polling)"]
    Matcher["RuleMatcher\n(wildcards → Regex)"]
    Automator["DefaultBrowserAutomator\n(AppleScript + AX)"]
    LocalServer["LocalServer\nlocalhost:10000"]
  end

  subgraph OS["macOS / External"]
    Browsers["Browsers\n(Safari/Chrome/Arc/...)"]
    EventKit["EventKit\n(Calendar)"]
    AppleScript["AppleScript\nAutomation"]
    AX["Accessibility API\n(AXUIElement)"]
  end

  Shell --> AppState
  Focus --> AppState
  RulesUI --> AppState
  SchedulesUI --> AppState
  PomodoroUI --> AppState
  CalendarUI --> AppState
  SettingsUI --> AppState

  AppState --> ReadModel
  AppState --> Facade
  Facade --> SessionC
  Facade --> SchedC
  Facade --> FocusC
  Facade --> RulesC
  Facade --> BlockingC

  SchedC --> ScheduleEngine
  FocusC --> PomodoroEngine
  FocusC --> PauseEngine
  RulesC --> RuleSetSvc
  CalendarSvc --> EventKit
  AppState --> CalendarSvc

  Bootstrap --> Store
  Persist --> Store
  Store -->|load on launch| AppState
  AppState -->|"observed changes"| Persist

  AppState -->|"TrustedState snapshot\n(isBlocking + allowedRules)"| Monitor
  Monitor --> Matcher
  Monitor --> Automator
  Automator --> AppleScript
  Automator --> AX
  AppleScript --> Browsers
  AX --> Browsers
  Automator -->|"redirect to localhost:10000"| Browsers
  Browsers --> LocalServer
```

---

## 2. Blocking Loop Flowchart

The core enforcement loop runs every 1.5 seconds on a background thread.

```mermaid
flowchart TD
  Start(["Timer fires\nevery 1.5s"])
  Snapshot["Read TrustedState snapshot\n(value type — thread-safe)"]
  CheckBlocking{isBlocking?}
  EarlyReturn(["Return\n(fast path)"])
  GetURL["automator.currentURL()\nAppleScript or AX API"]
  GotURL{URL obtained?}
  CheckAllowed["ruleMatcher.isAllowed(url,\nruleSet: snapshot.rules)"]
  IsAllowed{Allowed?}
  CheckCooldown{Redirect cooldown\n< 2s since last?}
  Skip(["Return\n(skip — avoid loop)"])
  Redirect["automator.redirect()\nto localhost:10000"]
  UpdateTime["Update lastRedirectTime\n(NSLock write)"]
  Done(["End tick"])

  Start --> Snapshot
  Snapshot --> CheckBlocking
  CheckBlocking -->|No| EarlyReturn
  CheckBlocking -->|Yes| GetURL
  GetURL --> GotURL
  GotURL -->|No| Done
  GotURL -->|Yes| CheckAllowed
  CheckAllowed --> IsAllowed
  IsAllowed -->|Yes| Done
  IsAllowed -->|No| CheckCooldown
  CheckCooldown -->|Yes| Skip
  CheckCooldown -->|No| Redirect
  Redirect --> UpdateTime
  UpdateTime --> Done
```

---

## 3. Session Start/Stop Flow

How a user action triggers blocking state across all layers.

```mermaid
sequenceDiagram
  participant User
  participant UI as AppKit UI
  participant AS as AppState
  participant Facade as LogicFacade
  participant Coord as Session Coordinator
  participant Persist as PersistenceCoordinator
  participant Monitor as BrowserMonitor

  User->>UI: Click "Start Focusing"
  UI->>AS: startManualSession()
  AS->>Facade: toggleSession()
  Facade->>Coord: startSession(ruleSetId:)
  Coord->>AS: isBlocking = true
  AS-->>UI: observation fires → render()
  AS-->>Persist: sink fires → UserDefaults.set(true)
  AS-->>Monitor: push TrustedState(isBlocking: true)
  Note over Monitor: Next tick: fast path skipped → enforcement active
```

---

## 4. Pomodoro State Machine

```mermaid
stateDiagram-v2
  [*] --> Idle : app launch

  Idle --> Focus : startPomodoro()
  Focus --> BreakTime : focus timer expires\n(auto-transition)
  BreakTime --> Focus : break timer expires\n(auto-restart)

  Focus --> Idle : stop()\n[strict: requires challenge]
  BreakTime --> Idle : stop()

  Focus --> Focus : skip break\n(goes to next focus)
  BreakTime --> Focus : skip break early

  state Focus {
    [*] --> Counting
    Counting --> GracePeriodLocked : 10s elapsed\n(strict mode only)
    GracePeriodLocked --> Counting : always counting
  }
```

---

## 5. Schedule Evaluation Flow

How scheduled blocks activate and deactivate blocking automatically.

```mermaid
flowchart TD
  Trigger(["Trigger:\nTimer tick (1Hz)\nor state change"])
  Debounce["debounce 100ms\n(cancel-and-restart Task)"]
  Evaluate["ScheduleEngine.activeSchedules(at: now)"]
  CalendarEvents["Merge calendar-imported\nvirtual schedules"]
  AnyActive{Any active\nschedule?}
  IsBlocking{Already\nblocking?}
  WasManual{Started\nmanually?}
  AutoStart["Auto-start session\n(wasStartedBySchedule = true)"]
  StillHaveActive{Schedule\nstill active?}
  AutoStop["Auto-stop session"]
  NoOp(["No change"])

  Trigger --> Debounce
  Debounce --> Evaluate
  Evaluate --> CalendarEvents
  CalendarEvents --> AnyActive
  AnyActive -->|Yes| IsBlocking
  AnyActive -->|No| StillHaveActive
  IsBlocking -->|No| AutoStart
  IsBlocking -->|Yes| NoOp
  StillHaveActive -->|Yes| NoOp
  StillHaveActive -->|No| WasManual
  WasManual -->|Yes, manual| NoOp
  WasManual -->|No, by schedule| AutoStop
```

---

## 6. Calendar Integration Flow

```mermaid
flowchart LR
  subgraph EventKit["EventKit (every 5 min)"]
    Fetch["Fetch events\nfor current week"]
  end

  subgraph ImportService["CalendarImportService"]
    TitleMatch["Match event title\nagainst import rules\n(contains / regex)"]
    Classify["Classify as\nfocus or break"]
    Suppress{Suppressed\nby user?}
    CreateSchedule["Create virtual\nSchedule entry"]
    Skip["Skip event"]
  end

  subgraph AppState["AppState"]
    Schedules["schedules array\n(user + virtual merged)"]
  end

  subgraph Engine["ScheduleEngine"]
    Evaluate["Evaluate merged\nschedules at now"]
  end

  Fetch --> TitleMatch
  TitleMatch -->|Match| Classify
  TitleMatch -->|No match| Skip
  Classify --> Suppress
  Suppress -->|Yes| Skip
  Suppress -->|No| CreateSchedule
  CreateSchedule --> Schedules
  Schedules --> Evaluate
```

---

## 7. URL Matching Flow

How `RuleMatcher` decides if a URL is allowed.

```mermaid
flowchart TD
  Input["Input URL\n(raw from browser)"]
  Normalize["Normalize:\n• strip www.\n• lowercase\n• remove trailing /"]
  ActiveRuleSet["Resolve active rule set\n(session > schedule > pomodoro priority)"]
  BuiltIns{Built-in flags\nenabled?}
  AddBuiltIns["Append built-in patterns:\n• search engines\n• AI providers\n• developer hosts"]
  CacheCheck{Regex built\nfor pattern?}
  BuildPredicate["Compile wildcard\nrule to Regex"]
  Cache["Store in\npredicate cache"]
  Evaluate["Evaluate predicate\nagainst normalized URL"]
  Allowed{Match found?}
  AllowResult(["ALLOW — no redirect"])
  BlockResult(["BLOCK — redirect to\nlocalhost:10000"])

  Input --> Normalize
  Normalize --> ActiveRuleSet
  ActiveRuleSet --> BuiltIns
  BuiltIns -->|Yes| AddBuiltIns
  BuiltIns -->|No| CacheCheck
  AddBuiltIns --> CacheCheck
  CacheCheck -->|Hit| Evaluate
  CacheCheck -->|Miss| BuildPredicate
  BuildPredicate --> Cache
  Cache --> Evaluate
  Evaluate --> Allowed
  Allowed -->|Yes| AllowResult
  Allowed -->|No| BlockResult
```

---

## 8. Threading Model

```mermaid
flowchart TB
  subgraph Main["Main Thread (@MainActor)"]
    Published["@Observable mutations\n(AppState)"]
    UIUpdate["AppKit UI updates\n(render())"]
    TimerCoord["AppStateTimerCoordinator\n(1Hz tick callbacks)"]
    AppleScriptExec["AppleScript execution"]
    AXCalls["AX API calls"]
    CalendarDispatch["Calendar fetch\ndispatch to main"]
  end

  subgraph BG["Background Threads"]
    MonitorTimer["BrowserMonitor\n(1.5s timer — global queue)"]
    LocalServerNet["LocalServer\n(NWListener — global queue)"]
    EventKitFetch["EventKit fetch\n(5-min timer)"]
  end

  subgraph Sync["Thread Sync Mechanisms"]
    NSLock1["NSLock\n(lastRedirectTime)"]
    NSLock2["NSLock\n(timer replacement)"]
    ValueSnapshot["Value-type snapshots\n(TrustedState struct)"]
    DispatchMain["DispatchQueue.main.async\n(calendar + monitor events)"]
  end

  MonitorTimer -->|reads| ValueSnapshot
  MonitorTimer -->|guarded by| NSLock1
  MonitorTimer -->|writes via| DispatchMain
  DispatchMain --> Published
  EventKitFetch -->|completes via| DispatchMain
  TimerCoord -->|fires on| Main
  LocalServerNet -->|async handlers| BG
```

---

## 9. Strict Mode — Quit Protection Flow

```mermaid
flowchart TD
  QuitRequest(["User requests quit\nor clicks Stop"])
  IsStrict{isStrict\nenabled?}
  IsBlocking{isBlocking\nactive?}
  NormalQuit(["Proceed normally"])
  ShowChallenge["Show challenge phrase dialog"]
  TypeChallenge["User types:\n'I am choosing to break my\nfocus and I acknowledge that\nthis may impact my productivity.'"]
  ExactMatch{Exact\nmatch?}
  Retry(["Shake animation\nretry"])
  TemporaryUnlock["Temporarily set\nisStrict = false"]
  PerformAction["Perform stop / quit"]
  RestoreStrict["Restore isStrict = true\n(unless user deactivated)"]

  QuitRequest --> IsStrict
  IsStrict -->|No| NormalQuit
  IsStrict -->|Yes| IsBlocking
  IsBlocking -->|No| NormalQuit
  IsBlocking -->|Yes| ShowChallenge
  ShowChallenge --> TypeChallenge
  TypeChallenge --> ExactMatch
  ExactMatch -->|No| Retry
  Retry --> TypeChallenge
  ExactMatch -->|Yes| TemporaryUnlock
  TemporaryUnlock --> PerformAction
  PerformAction --> RestoreStrict
```

---

## 10. Data Persistence Flow

```mermaid
flowchart LR
  subgraph Startup["App Launch"]
    BS["BootstrapService\nread all keys from UserDefaults"]
    Populate["Populate AppState\nobservable properties"]
  end

  subgraph Runtime["Runtime (observation trackers)"]
    Published["AppState observable\nproperty changes"]
    DropFirst["dropFirst()\nskip initial load value"]
    Sink["sink closure fires"]
    Write["SettingsStore.set(value, forKey:)"]
    UD["UserDefaults.standard"]
  end

  subgraph Models["Complex types"]
    Codable["Codable encode → JSON Data\n(schedules, ruleSets, etc.)"]
  end

  BS --> Populate
  Published --> DropFirst
  DropFirst --> Sink
  Sink --> Write
  Write --> Codable
  Codable --> UD
  BS --> UD
```

---

## 11. UI Observation Pattern

How AppKit view controllers stay in sync with `AppState`.

```mermaid
flowchart TD
  Props["AppState observable\nproperties relevant to view"]
  Merge["Publishers.MergeMany(...)"]
  Debounce["debounce 16ms\n(RunLoop.main)\n≈ 1 frame"]
  Sink["sink → render()"]
  Signature{Signature\nhash changed?}
  NoOp(["No-op\n(skip redundant render)"])
  Render["Read current AppState\nUpdate NSView / NSViewController\nsubviews"]

  Props --> Merge
  Merge --> Debounce
  Debounce --> Sink
  Sink --> Signature
  Signature -->|Same| NoOp
  Signature -->|Changed| Render
```

---

## 12. App Initialisation Sequence

```mermaid
sequenceDiagram
  participant Entry as FreeApp (@main)
  participant Runtime as FreeAppRuntime
  participant Factory as DependencyFactory
  participant AS as AppState
  participant Bootstrap as BootstrapService
  participant Store as SettingsStore
  participant Wire as RuntimeWiringCoordinator
  participant Monitor as BrowserMonitor
  participant Server as LocalServer

  Entry->>Runtime: init()
  Runtime->>Factory: build all dependencies\n(store, automator, calendar, server)
  Factory-->>Runtime: dependencies ready
  Runtime->>AS: init(dependencies)
  AS->>Bootstrap: loadPersistedState()
  Bootstrap->>Store: read all keys
  Store-->>Bootstrap: stored values
  Bootstrap-->>AS: populate observable props
  Runtime->>Wire: wire(monitor → appState)
  Wire->>Monitor: start(onEvent:)
  Monitor-->>Wire: events (trustedState changes)
  Runtime->>Server: start() on localhost:10000
  Server-->>Runtime: listening
  Runtime-->>Entry: app ready
```

---

* Free macOS App*
