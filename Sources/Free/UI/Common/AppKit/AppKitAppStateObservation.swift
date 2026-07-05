import Foundation
import Observation

enum AppKitAppStateObservation {
    // @MainActor classes are implicitly Sendable, so tracker instances can cross
    // into withObservationTracking's @Sendable onChange closure. Each tracker
    // intentionally keeps itself alive by re-arming from its own strong reference,
    // matching the previous local-function behavior.
    @MainActor
    private final class ShellAppearanceTracker {
        private let appState: AppState
        private let onChange: @MainActor () -> Void

        init(appState: AppState, onChange: @escaping @MainActor () -> Void) {
            self.appState = appState
            self.onChange = onChange
        }

        func startTracking() {
            withObservationTracking {
                _ = appState.accentColorIndex
                _ = appState.calendarIntegrationEnabled
                _ = appState.cursorFluidAnimationEnabled
                _ = appState.isStrict
            } onChange: { [self] in
                Task { @MainActor in
                    self.onChange()
                    self.startTracking()
                }
            }
        }
    }

    @MainActor
    private final class SignatureTracker<Signature: Equatable & Sendable> {
        private var lastSignature: Signature?
        private let signature: @MainActor () -> Signature
        private let onChange: @MainActor (Signature) -> Void

        init(
            signature: @escaping @MainActor () -> Signature,
            onChange: @escaping @MainActor (Signature) -> Void
        ) {
            self.signature = signature
            self.onChange = onChange
            lastSignature = signature()
        }

        func startTracking() {
            withObservationTracking {
                _ = signature()
            } onChange: { [self] in
                Task { @MainActor in
                    let newSignature = self.signature()
                    if newSignature != self.lastSignature {
                        self.lastSignature = newSignature
                        self.onChange(newSignature)
                    }
                    self.startTracking()
                }
            }
        }
    }

    @MainActor
    private final class PredicateTracker {
        private let readProperties: @MainActor () -> Bool
        private let onChange: @MainActor (Bool) -> Void

        init(
            readProperties: @escaping @MainActor () -> Bool,
            onChange: @escaping @MainActor (Bool) -> Void
        ) {
            self.readProperties = readProperties
            self.onChange = onChange
        }

        func startTrackingIfNeeded() {
            guard readProperties() else { return }
            startTracking()
        }

        private func startTracking() {
            withObservationTracking {
                _ = readProperties()
            } onChange: { [self] in
                Task { @MainActor in
                    let shouldContinue = self.readProperties()
                    self.onChange(shouldContinue)
                    if shouldContinue {
                        self.startTracking()
                    }
                }
            }
        }
    }

    @MainActor
    static func shellAppearancePublisher(appState: AppState) -> (@escaping @MainActor () -> Void) -> Void {
        return { onChange in
            ShellAppearanceTracker(appState: appState, onChange: onChange).startTracking()
        }
    }

    @MainActor
    static func observe<Signature: Equatable & Sendable>(
        appState: AppState,
        signature: @escaping @MainActor () -> Signature,
        onChange: @escaping @MainActor (_ signature: Signature) -> Void
    ) {
        SignatureTracker(signature: signature, onChange: onChange).startTracking()
    }

    @MainActor
    static func observe(
        appState: AppState,
        readProperties: @escaping @MainActor () -> Bool,
        onChange: @escaping @MainActor (_ dummy: Bool) -> Void
    ) {
        PredicateTracker(readProperties: readProperties, onChange: onChange).startTrackingIfNeeded()
    }
}
