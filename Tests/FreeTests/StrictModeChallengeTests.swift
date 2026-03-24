import AppKit
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct StrictModeChallengeTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "StrictModeChallengeTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @Test("StrictModeChallenge run returns false when cancel button clicked with empty input")
    @MainActor
    func runReturnsFalseOnCancelWithEmptyInput() {
        let appState = isolatedAppState(name: "cancelEmptyInput")
        let result = StrictModeChallenge.run(
            title: "Test",
            action: "test action",
            appState: appState,
            makeAlert: { NSAlert() },
            runAlert: { _ in .alertSecondButtonReturn }
        )
        #expect(result == false)
    }

    @Test("StrictModeChallenge run returns true when unlock button clicked with correct phrase")
    @MainActor
    func runReturnsTrueWithCorrectPhraseAndUnlockButton() {
        let appState = isolatedAppState(name: "correctPhrase")
        let result = StrictModeChallenge.run(
            title: "Test",
            action: "test action",
            appState: appState,
            makeAlert: { NSAlert() },
            runAlert: { alert in
                if let stack = alert.accessoryView?.subviews.first as? NSStackView,
                    let input = stack.arrangedSubviews.last as? NSTextField
                {
                    input.stringValue = AppState.challengePhrase
                }
                return .alertFirstButtonReturn
            }
        )
        #expect(result == true)
    }

    @Test("StrictModeChallenge run returns false when unlock button clicked with wrong phrase")
    @MainActor
    func runReturnsFalseWithWrongPhraseAndUnlockButton() {
        let appState = isolatedAppState(name: "wrongPhrase")
        let result = StrictModeChallenge.run(
            title: "Test",
            action: "test action",
            appState: appState,
            makeAlert: { NSAlert() },
            runAlert: { alert in
                if let stack = alert.accessoryView?.subviews.first as? NSStackView,
                    let input = stack.arrangedSubviews.last as? NSTextField
                {
                    input.stringValue = "wrong phrase"
                }
                return .alertFirstButtonReturn
            }
        )
        #expect(result == false)
    }

    @Test("StrictModeChallenge run returns false when cancel button clicked even with correct phrase")
    @MainActor
    func runReturnsFalseOnCancelWithCorrectPhrase() {
        let appState = isolatedAppState(name: "cancelWithCorrect")
        let result = StrictModeChallenge.run(
            title: "Test",
            action: "test action",
            appState: appState,
            makeAlert: { NSAlert() },
            runAlert: { alert in
                if let stack = alert.accessoryView?.subviews.first as? NSStackView,
                    let input = stack.arrangedSubviews.last as? NSTextField
                {
                    input.stringValue = AppState.challengePhrase
                }
                return .alertSecondButtonReturn
            }
        )
        #expect(result == false)
    }

    @Test("StrictModeChallenge alert is configured with Unlock and Cancel buttons")
    @MainActor
    func alertHasUnlockAndCancelButtons() {
        let appState = isolatedAppState(name: "buttonTitles")
        var capturedAlert: NSAlert?
        _ = StrictModeChallenge.run(
            title: "Emergency Unlock",
            action: "disable Strict Mode",
            appState: appState,
            makeAlert: {
                let alert = NSAlert()
                capturedAlert = alert
                return alert
            },
            runAlert: { _ in .alertSecondButtonReturn }
        )
        #expect(capturedAlert?.messageText == "Emergency Unlock")
        #expect(capturedAlert?.buttons.count == 2)
        #expect(capturedAlert?.buttons.first?.title == "Unlock")
        #expect(capturedAlert?.buttons.last?.title == "Cancel")
    }

    @Test("StrictModeChallenge accessory view contains an input text field")
    @MainActor
    func accessoryViewContainsInputTextField() {
        let appState = isolatedAppState(name: "accessoryView")
        var capturedAlert: NSAlert?
        _ = StrictModeChallenge.run(
            title: "Test",
            action: "test action",
            appState: appState,
            makeAlert: {
                let alert = NSAlert()
                capturedAlert = alert
                return alert
            },
            runAlert: { _ in .alertSecondButtonReturn }
        )
        let stack = capturedAlert?.accessoryView?.subviews.first as? NSStackView
        #expect(stack != nil)
        let inputField = stack?.arrangedSubviews.last as? NSTextField
        #expect(inputField != nil)
        #expect(inputField?.placeholderString == "Type the phrase...")
    }
}
