# Free - Distraction Blocker for macOS

**Free** is a native macOS application designed to help you regain focus by blocking distracting websites. It works on a "strict allowlist" principle: when Focus Mode is active, **everything is blocked** except for the specific URLs you explicitly allow.

## 🚀 Features

*   **Strict Blocking:** Blocks all websites by default when Focus Mode is ON.
*   **Multiple Allowed Lists:** Create personalized sets of URLs for different tasks.
*   **Open Tab Suggestions:** Instantly see and add URLs from all your currently open browser tabs.
*   **Smart Matching:** Precision matching prevents accidental leaks while automatically supporting subdomains, URL fragments (`#`), and multiple query parameters (`&`).
*   **Focus Schedules:** Automate your focus sessions with a full-featured weekly calendar.
*   **Pomodoro Timer:** Built-in timer with customizable focus and break intervals.
*   **Unblockable Mode:** A high-commitment mode that prevents disabling focus without completing a text-based challenge.
*   **External Calendar Sync:** Automatically treat meetings as "Breaks" using the `CalendarProvider` protocol.
*   **Professional Installation:** Automatically offers to move itself to your `/Applications` folder for stability.
*   **Decoupled & Tested:** Built with a testable architecture and backed by **107 passing unit tests**.

## 📅 Scheduling & Automation

The app features a powerful, interactive weekly calendar to manage your focus time:

*   **Interactive Grid:** A 7-day, 24-hour view of your week with Sunday/Monday start options.
*   **Drag to Create:** Click and drag to define custom durations with 15-minute snapping.
*   **Smart Overrides:** Manual pauses and "Break" schedules intelligently override focus sessions.
*   **Smart Splitting:** Edit recurring schedules globally or for specific days only.

## 🛠 Installation & Building

The app is built using Swift and SwiftUI.

### Prerequisites
*   macOS 14.0 or later.
*   Xcode Command Line Tools installed.

### Development Build
```bash
./build.sh
```

### Packaging for Distribution
To create an optimized Release build and generate a `.dmg` with:
* `Free.app`
* `/Applications` shortcut

```bash
./package.sh
```

### Running Tests
To verify the app's logic and stability:
```bash
swift test
```
The suite runs 100+ tests in under 1 second.

## 🚦 Usage

1.  **Install from DMG:** Open the disk image and drag `Free.app` to your `/Applications` folder.
2.  **Launch the App:** Open `Free.app` from `/Applications`.
3.  **Grant Permissions:** Provide Accessibility and Automation permissions when prompted.
4.  **Manage Rules:** Use **Allowed Websites** to define what you need to work.
5.  **Start Focusing:** Toggle manual mode, start a Pomodoro, or let your **Schedules** automate your day.

## 🔧 Technical Details

*   **Language:** Swift 6 (SwiftUI)
*   **Decoupled Architecture:** Core logic is abstracted into testable protocols (`BrowserAutomator`, `CalendarProvider`), making the app highly resilient to regressions.
*   **Mechanism:** Checks active window state every 1 second and uses AppleScript for high-precision URL detection and redirection.
*   **Data Integrity:** Isolated `UserDefaults` suites for testing ensure that development doesn't affect your personal app settings.
---
Built with focus in mind. 🛡️
