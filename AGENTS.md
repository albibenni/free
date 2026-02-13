# AGENTS.md - Project Context & Architecture

This document outlines the architecture, implementation details, and roadmap for **Free**, a macOS distraction blocker.

## 1. Technical Implementation
We have selected **Option 2: Process Monitor (Swift + AppleScript)** for this project.

*   **Approach:** The app runs as a background process with a UI. It polls the active application state every 1 second.
*   **Detection:** It identifies if the frontmost app is a supported browser (Safari, Chrome, Brave, etc.) and uses **AppleScript** (via Accessibility APIs) to read the URL from the address bar.
*   **Scheduling:** Uses a polling mechanism combined with `EventKit` to monitor internal focus schedules and external system calendar events.
*   **Enforcement:**
    *   **Logic:** If a URL is not in the allowlist AND focus mode is active (either manually or via schedule), the app uses AppleScript to **redirect** the tab to a local block page (`http://localhost:10000`).
    *   **Overrides:** "Break" sessions (internal) and any external calendar events (e.g., Google Calendar meetings) act as high-priority overrides that temporarily disable blocking even during focus windows.

## 2. Core Functionality (Current Status)

### ✅ Implemented
*   **Multiple Personalized Allowed Lists:** Users can create multiple named sets of allowed URLs and assign them to specific schedules or manual focus sessions.
*   **Open Tab Suggestions:** Real-time URL suggestions fetched from ALL open tabs across all supported browsers for rapid list configuration.
*   **Smart URL Matching:** High-precision matching logic that prevents partial-word leaks (e.g., "work" vs "working") while automatically supporting all subdomains.
*   **Customizable Themes:** Full support for Light, Dark, and System appearance modes, including an adaptive local block page.
*   **Automated Quality Assurance:** Comprehensive unit test suite using the new **Swift Testing** framework, integrated into a **Husky** pre-commit pipeline to ensure build and logic stability.
*   **Allowlist Logic (Strict Mode):** Everything is blocked unless explicitly added to the active rules list.
*   **Real-time Monitoring:** Blocks content within ~1 second of navigation.
*   **Interactive Weekly Calendar:** Google Calendar-style grid with drag-to-create, 15-minute snapping, and real-time time overlays.
*   **Smart Automation:**
    *   **Focus vs Break:** Support for different session types.
    *   **Calendar Sync:** Integration with native macOS Calendar (EventKit) to treat meetings as breaks.
    *   **Schedule Splitting:** Ability to modify single occurrences of recurring schedules.
*   **Pomodoro Timer:** Fully integrated timer with Focus and Break phases.
    *   **Strict Mode:** When "Unblockable Mode" is active, the timer is locked for both phases (2-second grace period).
*   **User Customization:** Personalized session colors and configurable week start (Monday vs Sunday).
*   **Browser Support:** Extensive support for Chromium-based browsers and Safari.

### 🚧 Roadmap / Future Features
*   **Blocklists:** Option to invert logic (Allow everything *except* bad sites).
*   **Lockdown Mode:** Prevent quitting the app or disabling permissions during a session.

## 3. User Workflows
*   **Focus Session:** User toggles "Focus Mode" on manually, or defines a schedule. They can only access tools required for their work.
*   **Dynamic Breaks:** If a user has a meeting on their Google Calendar, the app automatically unblocks the browser for that window, then re-engages focus mode once the meeting ends.
*   **Emergency Access:** The user can toggle mode off manually (unless "Unblockable" mode is active, which requires a text-based challenge).
