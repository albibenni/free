# AGENTS.md - Project Context & Architecture

This document outlines the architecture, implementation details, and roadmap for **Free**, a macOS distraction blocker.

## 1. Technical Implementation
We have selected **Option 2: Process Monitor (Swift + AppleScript)** for this project.

*   **Approach:** The app runs as a background process with a UI. It polls the active application state every 1 second.
*   **Detection:** It identifies if the frontmost app is a supported browser (Safari, Chrome, Brave, etc.) and uses **AppleScript** (via Accessibility APIs) to read the URL from the address bar.
*   **Enforcement:**
    *   **Current:** If a URL is not in the allowlist, the app uses AppleScript to **redirect** the tab to a local block page (`http://localhost:10000`).
    *   **Reasoning:** This avoids the complexity and signing requirements of the Screen Time API or specific Browser Extensions, allowing for a single app that works across multiple browsers immediately.

## 2. Core Functionality (Current Status)

### ✅ Implemented
*   **Allowlist Logic (Strict Mode):** The app operates on a "deny all, allow some" basis. Everything is blocked unless explicitly added to the rules list.
*   **Real-time Monitoring:** Blocks content within ~1 second of navigation.
*   **User Feedback:** Redirects to a visual "Focus Mode Active" HTML page instead of silently closing tabs.
*   **Browser Support:** Extensive support for Chromium-based browsers and Safari.

### 🚧 Roadmap / Future Features
*   **Blocklists:** Option to invert logic (Allow everything *except* bad sites).
*   **Lockdown Mode:** Prevent quitting the app or disabling permissions during a session.
*   **Scheduled Blocking:** Calendar-based (9 AM – 5 PM) automation.
*   **Pomodoro Timer:** Integration with short-term focus timers.

## 3. User Workflows
*   **Focus Session:** User toggles "Focus Mode" on. They can only access tools required for their work (e.g., Figma, localhost, specific documentation).
*   **Emergency Access:** Currently, the user can toggle the mode off at any time. Future updates may restrict this ("Nuclear Option").