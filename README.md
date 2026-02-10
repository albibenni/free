# Free - Distraction Blocker for macOS

**Free** is a native macOS application designed to help you regain focus by blocking distracting websites. It works on a "strict allowlist" principle: when Focus Mode is active, **everything is blocked** except for the specific URLs you explicitly allow.

## 🚀 Features

*   **Strict Blocking:** Blocks all websites by default when Focus Mode is ON.
*   **Multiple Allowed Lists:** Create personalized sets of URLs for different tasks (e.g., "Work", "Research", "Dev"). Assign specific lists to schedules or select them manually for quick sessions.
*   **Focus Schedules:** Automate your focus sessions with a full-featured weekly calendar.
*   **Pomodoro Timer:** Built-in timer with customizable focus and break intervals.
*   **Unblockable Mode:** A high-commitment mode that prevents disabling focus or stopping the Pomodoro timer without completing a text-based challenge.
*   **External Calendar Sync:** Integrate with Google Calendar (via macOS System Events) to automatically treat meetings as "Breaks."
*   **Redirect, Don't Close:** Blocked pages are redirected to a local "Focus Mode" screen, preventing you from losing your tabs completely.
*   **Wide Browser Support:** Works with Safari, Chrome, Brave, Edge, Arc, Opera, and Vivaldi.
*   **Native UI:** Clean macOS interface with both a Window and Menu Bar icon.

## 📅 Scheduling & Automation

The app features a powerful, interactive weekly calendar to manage your focus time:

*   **Interactive Grid:** A 7-day, 24-hour view of your week. Use the Settings to choose between a Monday or Sunday start.
*   **Quick Add:** Single-click any empty slot to automatically open the editor for a 1-hour session.
*   **Drag to Create:** Click and drag to visually define custom durations with 15-minute snapping and real-time time overlays.
*   **Focus vs. Break:** Define sessions as "Focus" (strict blocking) or "Break" (unblocked access). Breaks intelligently override scheduled focus sessions.
*   **Schedule-Linked Rules:** Assign a specific "Allowed List" to each schedule, so you only have access to the tools needed for that specific block of time.
*   **Smart Splitting:** When editing a recurring schedule from a specific day, choose to modify "All Days" or "Only This Day" to handle one-off changes.
*   **Personalization:** Color-code your sessions to distinguish between different types of work or personal time.
*   **Calendar Import:** Enable "Calendar Integration" in Settings to see your real-world meetings on the grid. Any active calendar event automatically acts as a break.

## 🛠 Installation & Building

The app is built using Swift and SwiftUI. No external dependencies (CocoaPods/SPM) are required.

### Prerequisites
*   macOS 15.0 (Sequoia) or later.
*   Xcode Command Line Tools installed (`xcode-select --install`).

### Build Command
Run the included build script to compile the app:

```bash
./build.sh
```

This will create `Free.app` in the current directory.

## 🚦 Usage

1.  **Launch the App:**
    ```bash
    open Free.app
    ```
2.  **Manage Allowed Lists:**
    *   Click on **Allowed Websites** to open the manager.
    *   Create multiple lists (e.g., "Deep Work", "Learning").
    *   Use the toggleable sidebar to switch between and organize your lists.
3.  **Grant Permissions:**
    *   **Accessibility:** Required to read the current URL from your browser. The app will show a red warning banner if this is missing.
    *   **Automation:** Required to redirect the browser tab. macOS will prompt you ("Free wants to control Safari...") the first time you use it.
    *   **Calendar (Optional):** Required only if you enable "Calendar Integration" in Settings to sync with your meetings.

4.  **Start Focusing:**
    *   Toggle **Focus Mode** to ON, start a **Pomodoro**, or set up a **Schedule**.
    *   **Strict Mode:** Enable "Unblockable Mode" in Settings to make the session (and the timer) truly unstoppable.
    *   **Matching Logic:**
        *   **Simple Match:** Enter a domain or keyword (e.g., `google.com`). This matches any URL *containing* that string (case-insensitive).
        *   **Wildcard Match:** Use `*` for pattern matching. For example, `https://www.youtube.com/watch*` will match any YouTube video URL.

## 🔧 Technical Details

*   **Language:** Swift 5 (SwiftUI)
*   **Mechanism:**
    *   **Poller:** Checks the active window every 1 second.
    *   **AppleScript:** Uses AppleScript via `NSAppleScript` to read the URL from supported browsers and to perform the redirect.
    *   **EventKit:** Integrates with the native macOS Calendar database to fetch and monitor external events.
    *   **Local Server:** Runs a lightweight TCP server on port `10000` to serve the block page.
*   **Supported Browsers:** Safari, Chrome, Brave, Edge, Arc, Opera, and Vivaldi.

## ⚠️ Troubleshooting

**"The app is damaged and can't be opened"**
This happens because the app is ad-hoc signed locally. Run this command to fix it:
```bash
codesign -s - --deep --force Free.app
```

**Blocking isn't working?**
1.  Check the "Accessibility Permission Needed" banner in the app.
2.  If permissions look correct but it fails, remove "Free" from *System Settings > Privacy & Security > Accessibility* and add it again.
3.  Check logs: `cat /tmp/free_app.log`