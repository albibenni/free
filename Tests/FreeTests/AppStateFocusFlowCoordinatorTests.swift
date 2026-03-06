import Foundation
import Testing

@testable import FreeLogic

struct AppStateFocusFlowCoordinatorTests {
    @Test("startPomodoro and startBreak return run-timer transitions")
    func startTransitions() {
        let pomodoroState = PomodoroEngine.State(
            status: .none,
            remaining: 0,
            startedAt: nil,
            ruleSetId: nil
        )

        let started = AppStateFocusFlowCoordinator.startPomodoro(
            state: pomodoroState,
            focusDurationMinutes: 25,
            activeRuleSetId: nil,
            ruleSets: [RuleSet.defaultSet()]
        )
        #expect(started.shouldRunTimer)
        #expect(started.state.status == .focus)

        let broken = AppStateFocusFlowCoordinator.startBreak(
            state: started.state,
            breakDurationMinutes: 5
        )
        #expect(broken.shouldRunTimer)
        #expect(broken.state.status == .breakTime)
    }

    @Test("stopPomodoroIfUnlocked returns nil when locked and stop/check flags when unlocked")
    func stopTransition() {
        let focusState = PomodoroEngine.State(
            status: .focus,
            remaining: 60,
            startedAt: Date().addingTimeInterval(-120),
            ruleSetId: UUID()
        )

        #expect(
            AppStateFocusFlowCoordinator.stopPomodoroIfUnlocked(
                state: focusState,
                isLocked: true
            ) == nil
        )

        let stopped = AppStateFocusFlowCoordinator.stopPomodoroIfUnlocked(
            state: focusState,
            isLocked: false
        )
        #expect(stopped?.shouldStopTimer == true)
        #expect(stopped?.shouldCheckSchedules == true)
        #expect(stopped?.state.status == AppState.PomodoroStatus.none)
    }

    @Test("pause transitions cover start guard and cancel behavior")
    func pauseTransitions() {
        let initial = PauseEngine.State(isPaused: false, remaining: 0)

        #expect(
            AppStateFocusFlowCoordinator.startPause(
                state: initial,
                minutes: 5,
                isBlocking: false
            ) == nil
        )

        let started = AppStateFocusFlowCoordinator.startPause(
            state: initial,
            minutes: 5,
            isBlocking: true
        )
        #expect(started?.shouldStartTimer == true)
        #expect(started?.state.isPaused == true)

        let cancelled = AppStateFocusFlowCoordinator.cancelPause(
            state: started?.state ?? initial
        )
        #expect(cancelled.shouldStopTimer)
        #expect(!cancelled.state.isPaused)
    }

    @Test("skip phase action maps pomodoro status branches")
    func skipPhaseAction() {
        #expect(AppStateFocusFlowCoordinator.skipPhaseAction(for: .focus) == .startBreak)
        #expect(AppStateFocusFlowCoordinator.skipPhaseAction(for: .breakTime) == .startFocus)
        #expect(AppStateFocusFlowCoordinator.skipPhaseAction(for: .none) == .none)
    }

    @Test("tick transitions bridge runtime coordinators for pomodoro and pause")
    func tickTransitions() {
        #expect(
            AppStateFocusFlowCoordinator.pomodoroTickAction(status: .focus, remaining: 5)
                == .decrement
        )
        #expect(
            AppStateFocusFlowCoordinator.pomodoroTickAction(status: .focus, remaining: 0)
                == .startBreak
        )
        #expect(
            AppStateFocusFlowCoordinator.pomodoroTickAction(status: .breakTime, remaining: 0)
                == .startFocus
        )

        let pauseState = PauseEngine.State(isPaused: true, remaining: 1)
        let runningTick = AppStateFocusFlowCoordinator.pauseTick(state: pauseState)
        #expect(runningTick.state.isPaused == true)
        #expect(runningTick.state.remaining == 0)
        #expect(runningTick.shouldCancelPause == false)

        let cancelTick = AppStateFocusFlowCoordinator.pauseTick(
            state: PauseEngine.State(isPaused: true, remaining: 0)
        )
        #expect(cancelTick.state.isPaused == false)
        #expect(cancelTick.shouldCancelPause == true)
    }
}
