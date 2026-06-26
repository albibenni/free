import Foundation
import Observation

enum AppKitAppStateObservation {
@MainActor
    static func shellAppearancePublisher(appState: AppState) -> (@escaping @MainActor () -> Void) -> Void {
        return { onChange in
            @MainActor func startTracking() {
                withObservationTracking {
                    MainActor.assumeIsolated {
                        _ = appState.accentColorIndex
                        _ = appState.calendarIntegrationEnabled
                        _ = appState.cursorFluidAnimationEnabled
                        _ = appState.isStrict
                    }
                } onChange: {
                    DispatchQueue.main.async {
                        print("SHELL APPEARANCE CHANGED")
                        onChange()
                        startTracking()
                    }
                }
            }
            startTracking()
        }
    }

    @MainActor
    static func observe<Signature: Equatable>(
        appState: AppState,
        signature: @escaping @MainActor () -> Signature,
        onChange: @escaping @MainActor (_ signature: Signature) -> Void
    ) {
        var lastSignature: Signature? = nil
        
        @MainActor func startTracking() {
            withObservationTracking {
                MainActor.assumeIsolated {
                    _ = signature()
                }
            } onChange: {
                DispatchQueue.main.async {
                    let newSignature = signature()
                    if newSignature != lastSignature {
                        lastSignature = newSignature
                        onChange(newSignature)
                    }
                    startTracking()
                }
            }
        }
        
        lastSignature = signature()
        startTracking()
    }
    
    @MainActor
    static func observe(
        appState: AppState,
        readProperties: @escaping @MainActor () -> Bool,
        onChange: @escaping @MainActor (_ dummy: Bool) -> Void
    ) {
        @MainActor func startTracking() {
            withObservationTracking {
                MainActor.assumeIsolated {
                    _ = readProperties()
                }
            } onChange: {
                DispatchQueue.main.async {
                    let shouldContinue = readProperties()
                    onChange(shouldContinue)
                    if shouldContinue {
                        startTracking()
                    }
                }
            }
        }
        let shouldContinue = readProperties()
        if shouldContinue {
            startTracking()
        }
    }
}
