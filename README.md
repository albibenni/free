# Free - Distraction Blocker for macOS

**Free** is a native macOS application designed to help you regain focus by blocking distracting websites. It works on a "strict allowlist" principle: when Focus Mode is active, **everything is blocked** except for the specific URLs you explicitly allow.

## 🚀 Features

*   **Strict Blocking:** Blocks all websites by default when Focus Mode is ON.
*   **Allowlist Rules:** Define specific URLs (e.g., specific YouTube videos or work domains) that are allowed.
*   **Redirect, Don't Close:** Blocked pages are redirected to a local "Focus Mode" screen, preventing you from losing your tabs completely.
*   **Wide Browser Support:** Works with Safari, Chrome, Brave, Edge, Arc, Opera, and Vivaldi.
*   **Native UI:** Clean macOS interface with both a Window and Menu Bar icon.

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
2.  **Grant Permissions:**
    *   **Accessibility:** Required to read the current URL from your browser. The app will show a red warning banner if this is missing. Click "Grant" or go to *System Settings > Privacy & Security > Accessibility*.
    *   **Automation:** Required to redirect the browser tab. macOS will prompt you ("Free wants to control Safari...") the first time you use it. Click "OK".

3.  **Start Focusing:**
    *   Add allowed URLs in the main window (e.g., `google.com`, `localhost`).
    *   Toggle **Focus Mode** to ON.
    *   Any website not in your list will now be redirected to the "Blocked" screen.

## 🔧 Technical Details

*   **Language:** Swift 5 (SwiftUI)
*   **Mechanism:**
    *   **Poller:** Checks the active window every 1 second.
    *   **AppleScript:** Uses AppleScript via `NSAppleScript` to read the URL from supported browsers and to perform the redirect.
    *   **Local Server:** Runs a lightweight TCP server on port `10000` to serve the block page (`http://localhost:10000`).
*   **Supported Browsers:**
    *   Safari (`com.apple.Safari`)
    *   Google Chrome (`com.google.Chrome`)
    *   Brave (`com.brave.Browser`)
    *   Microsoft Edge (`com.microsoft.edgemac`)
    *   Arc (`company.thebrowser.Browser`)
    *   Opera (`com.operasoftware.Opera`)
    *   Vivaldi (`com.vivaldi.Vivaldi`)

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
