# AGENTS.md - Project Context & Architecture

This document outlines the architecture, implementation details, and roadmap for **Free**, a macOS distraction blocker.

## 1. Technical Implementation
We have selected **Option 2: Process Monitor (Swift + AppleScript)** for this project.

*   **Approach:** The app runs as a background process with a UI. It polls the active application state every 1 second.
*   **Detection:** It identifies if the frontmost app is a supported browser (Safari, Chrome, Brave, etc.) and uses **AppleScript** (via Accessibility APIs) to read the URL from the address bar.
*   **Decoupled Architecture:** The system is split into testable protocols:
    *   `BrowserAutomator`: Abstracts away AppleScript/Accessibility APIs.
    *   `CalendarProvider`: Decouples business logic from macOS `EventKit`.
    *   `LocalServer`: A standalone TCP server for serving the block page.
*   **Enforcement:**
    *   **Logic:** If a URL is not in the allowlist AND focus mode is active (either manually or via schedule), the app uses AppleScript to **redirect** the tab to a local block page (`http://localhost:10000`).
    *   **Overrides:** "Break" sessions (internal), manual pauses, and external calendar events act as overrides that temporarily disable blocking.

## 2. Core Functionality (Current Status)

### ✅ Implemented
*   **Multiple Personalized Allowed Lists:** Users can create multiple named sets of allowed URLs and assign them to specific schedules.
*   **Open Tab Suggestions:** Real-time URL suggestions fetched from ALL open tabs across all supported browsers.
*   **Smart URL Matching:** High-precision matching logic supporting subdomains, path segments (`/`, `?`, `#`, `&`), and advanced wildcards (`*`).
*   **Customizable Themes:** Full support for Light, Dark, and System modes.
*   **Automated Quality Assurance:** Comprehensive suite of **107 unit tests** covering 100% of logic-heavy components and UI transformations.
*   **Interactive Weekly Calendar:** Google Calendar-style grid with drag-to-create, 15-minute snapping, and stable chronological sorting.
*   **Smart Automation:**
    *   **Focus vs Break:** Support for different session types.
    *   **Calendar Sync:** Integration with native macOS Calendar (EventKit).
    *   **Schedule Splitting:** Ability to modify single occurrences of recurring schedules.
*   **Pomodoro Timer:** Fully integrated timer with a 10-second grace period and strict mode challenges.
*   **Auto-Installation:** Detects if running from a DMG and offers to move itself to the `/Applications` folder.
*   **Professional Packaging:** Optimized release build process generating a standard macOS `.dmg` with installation shortcuts.

### 🚧 Roadmap / Future Features
*   **Blocklists:** Option to invert logic (Allow everything *except* bad sites).
*   **Lockdown Mode:** Prevent quitting the app or disabling permissions during a session.

## 3. User Workflows
*   **Focus Session:** User toggles "Focus Mode" on manually, or defines a schedule.
*   **Emergency Access:** The user can toggle mode off manually (unless "Unblockable" mode is active, which requires a text-based challenge).
*   **Automatic Installation:** When a user first opens the DMG, the app guides them to install it correctly in their Applications folder to ensure permission stability.
