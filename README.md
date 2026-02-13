# Free - Distraction Blocker for macOS

**Free** is a native macOS application designed to help you regain focus by blocking distracting websites. It works on a "strict allowlist" principle: when Focus Mode is active, **everything is blocked** except for the specific URLs you explicitly allow.

## 🚀 Features

*   **Strict Blocking:** Blocks all websites by default when Focus Mode is ON.
*   **Multiple Allowed Lists:** Create personalized sets of URLs for different tasks (e.g., "Work", "Research", "Dev"). Assign specific lists to schedules or select them manually for quick sessions.
*   **Open Tab Suggestions:** Instantly see and add URLs from all your currently open browser tabs across all windows.
*   **Smart Matching:** Precision matching prevents accidental leaks (e.g., "work" won't match "working") while automatically supporting all subdomains.
*   **Customizable Themes:** Switch between Light, Dark, and System appearance modes. The local block page adapts automatically.
*   **Focus Schedules:** Automate your focus sessions with a full-featured weekly calendar.
*   **Pomodoro Timer:** Built-in timer with customizable focus and break intervals.
*   **Unblockable Mode:** A high-commitment mode that prevents disabling focus or stopping the Pomodoro timer without completing a text-based challenge.
*   **External Calendar Sync:** Integrate with Google Calendar (via macOS System Events) to automatically treat meetings as "Breaks."
*   **Redirect, Don't Close:** Blocked pages are redirected to a local "Focus Mode" screen, preventing you from losing your tabs completely.
*   **Wide Browser Support:** Works with Safari, Chrome, Brave, Edge, Arc, Opera, and Vivaldi.
*   **Reliable Infrastructure:** Built-in automated tests and a Husky-powered pre-commit pipeline ensure the app remains stable and bug-free.
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

The app is built using Swift and SwiftUI.

### Prerequisites
*   macOS 15.0 (Sequoia) or later.
*   Xcode Command Line Tools installed (`xcode-select --install`).
*   pnpm (optional, for pre-commit hooks).

### Build Command
Run the included build script to compile the app:

```bash
./build.sh
```

This will create `Free.app` in the current directory.

### Running Tests
To verify the app's logic and stability:
```bash
swift test
```

## 🚦 Usage

1.  **Launch the App:**
    ```bash
    open Free.app
    ```
2.  **Manage Allowed Lists:**
    *   Click on **Allowed Websites** to open the manager.
    *   **Quick Add:** Expand the "Open Tabs Suggestions" section to see URLs from all your open browser tabs. Click "Add" to include them in your list instantly.
    *   Use the toggleable sidebar to switch between and organize your lists.
3.  **Appearance:**
    *   Go to Settings to choose between **Light**, **Dark**, or **System** theme.
4.  **Grant Permissions:**
    *   **Accessibility:** Required to read URLs. The app shows a warning banner if this is missing.
    *   **Automation:** Required to redirect browser tabs.
    *   **Calendar (Optional):** Required for meeting synchronization.

5.  **Start Focusing:**
    *   Toggle **Focus Mode** to ON, start a **Pomodoro**, or set up a **Schedule**.
    *   **Strict Mode:** Enable "Unblockable Mode" in Settings to make sessions truly unstoppable.
    *   **Matching Logic:**
        *   **Segment Matching:** Rules are precise. `google.com` allows all subdomains (like `mail.google.com`) but won't match different words like `google.community`.
        *   **Wildcard Match:** Use `*` for broad pattern matching.

## 🔧 Technical Details

*   **Language:** Swift 6 (SwiftUI)
*   **Quality Assurance:**
    *   **Swift Testing:** Modern unit test suite for core logic.
    *   **Husky:** Pre-commit pipeline running build checks and tests.
*   **Mechanism:**
    *   **Poller:** Checks active window state every 1 second.
    *   **AppleScript:** Robust multi-browser support for tab reading and redirection.
    *   **EventKit:** Native macOS Calendar integration.
    *   **Local Server:** Lightweight TCP server serving the adaptive Light/Dark block page.
*   **Supported Browsers:** Safari, Chrome, Brave, Edge, Arc, Opera, and Vivaldi.