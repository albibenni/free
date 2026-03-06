import Foundation

struct AppStateLogicFacade {
    typealias SessionState = AppStateSessionCoordinator.SessionState
    typealias RuleContext = AppStateReadModelCoordinator.RuleContext
    typealias RuleMutation = AppStateRuleSetCoordinator.RuleMutation
    typealias ScheduleDeleteResult = AppStateScheduleMutationCoordinator.DeletionResult
    typealias ChallengeStopResult = AppStateChallengeCoordinator.StopPomodoroResult
    typealias ChallengeDisableResult = AppStateChallengeCoordinator.DisableUnblockableResult
    typealias PomodoroTransition = AppStateFocusFlowCoordinator.PomodoroTransition
    typealias SkipPhaseAction = AppStateFocusFlowCoordinator.SkipPhaseAction
    typealias PauseTransition = AppStateFocusFlowCoordinator.PauseTransition
    typealias PauseTickTransition = AppStateFocusFlowCoordinator.PauseTickTransition
    typealias PomodoroTickAction = AppStateFocusFlowCoordinator.PomodoroTickAction

    static let live = AppStateLogicFacade()

    func makeSessionState(
        isBlocking: Bool,
        wasStartedBySchedule: Bool,
        manuallyPausedScheduleIds: Set<UUID>
    ) -> SessionState {
        SessionState(
            isBlocking: isBlocking,
            wasStartedBySchedule: wasStartedBySchedule,
            manuallyPausedScheduleIds: manuallyPausedScheduleIds
        )
    }

    func migrateLegacyBlockingSourceIfNeeded(
        hasPersistedWasStartedBySchedule: Bool,
        current: SessionState,
        schedules: [Schedule],
        pomodoroStatus: AppState.PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isUnblockable: Bool,
        calendarImportsBlockTime: Bool,
        calendarEvents: [ExternalEvent]
    ) -> SessionState? {
        AppStateSessionCoordinator.migrateLegacyBlockingSourceIfNeeded(
            hasPersistedWasStartedBySchedule: hasPersistedWasStartedBySchedule,
            current: current,
            schedules: schedules,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isUnblockable: isUnblockable,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarEvents
        )
    }

    func toggleSession(
        current: SessionState,
        isUnblockable: Bool,
        schedules: [Schedule]
    ) -> SessionState {
        AppStateSessionCoordinator.toggle(
            current: current,
            isUnblockable: isUnblockable,
            schedules: schedules
        )
    }

    func checkSession(
        current: SessionState,
        schedules: [Schedule],
        pomodoroStatus: AppState.PomodoroStatus,
        calendarIntegrationEnabled: Bool,
        isUnblockable: Bool,
        calendarImportsBlockTime: Bool,
        calendarEvents: [ExternalEvent]
    ) -> SessionState {
        AppStateSessionCoordinator.check(
            current: current,
            schedules: schedules,
            pomodoroStatus: pomodoroStatus,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            isUnblockable: isUnblockable,
            calendarImportsBlockTime: calendarImportsBlockTime,
            calendarEvents: calendarEvents
        )
    }

    func mutateRule(
        _ rule: String,
        setId: UUID,
        currentRuleSets: [RuleSet],
        isStrictActive: Bool,
        mutation: RuleMutation
    ) -> [RuleSet] {
        AppStateRuleSetCoordinator.mutateRule(
            rule,
            setId: setId,
            currentRuleSets: currentRuleSets,
            isStrictActive: isStrictActive,
            mutation: mutation
        )
    }

    func deleteRuleSet(
        id: UUID,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?,
        isStrictActive: Bool
    ) -> AppStateRuleSetCoordinator.RuleSetSelectionResult {
        AppStateRuleSetCoordinator.deleteRuleSet(
            id: id,
            currentRuleSets: currentRuleSets,
            currentActiveRuleSetId: currentActiveRuleSetId,
            isStrictActive: isStrictActive
        )
    }

    func createRuleSet(
        name: String,
        makeActive: Bool,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?
    ) -> AppStateRuleSetCoordinator.RuleSetCreationResult {
        AppStateRuleSetCoordinator.createRuleSet(
            name: name,
            makeActive: makeActive,
            currentRuleSets: currentRuleSets,
            currentActiveRuleSetId: currentActiveRuleSetId
        )
    }

    func selectActiveRuleSet(
        _ id: UUID,
        currentRuleSets: [RuleSet],
        currentActiveRuleSetId: UUID?,
        isStrictActive: Bool
    ) -> UUID? {
        AppStateRuleSetCoordinator.selectActiveRuleSet(
            id,
            currentRuleSets: currentRuleSets,
            currentActiveRuleSetId: currentActiveRuleSetId,
            isStrictActive: isStrictActive
        )
    }

    func saveSchedule(
        currentSchedules: [Schedule],
        name: String,
        days: Set<Int>,
        date: Date?,
        start: Date,
        end: Date,
        color: Int,
        type: ScheduleType,
        ruleSet: UUID?,
        existingId: UUID?,
        modifyAllDays: Bool,
        initialDay: Int?
    ) -> [Schedule] {
        AppStateScheduleMutationCoordinator.saveSchedule(
            currentSchedules: currentSchedules,
            name: name,
            days: days,
            date: date,
            start: start,
            end: end,
            color: color,
            type: type,
            ruleSet: ruleSet,
            existingId: existingId,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        )
    }

    func updateScheduleOccurrence(
        currentSchedules: [Schedule],
        id: UUID,
        originalDay: Int,
        targetDay: Int,
        targetDate: Date?,
        start: Date,
        end: Date
    ) -> [Schedule] {
        AppStateScheduleMutationCoordinator.updateScheduleOccurrence(
            currentSchedules: currentSchedules,
            id: id,
            originalDay: originalDay,
            targetDay: targetDay,
            targetDate: targetDate,
            start: start,
            end: end
        )
    }

    func deleteSchedule(
        currentSchedules: [Schedule],
        id: UUID,
        modifyAllDays: Bool,
        initialDay: Int?,
        suppressedImportedCalendarEventKeys: Set<String>
    ) -> ScheduleDeleteResult {
        AppStateScheduleMutationCoordinator.deleteSchedule(
            currentSchedules: currentSchedules,
            id: id,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys
        )
    }

    func stopPomodoroChallenge(
        phrase: String,
        challengePhrase: String,
        currentIsUnblockable: Bool
    ) -> ChallengeStopResult {
        AppStateChallengeCoordinator.stopPomodoro(
            phrase: phrase,
            challengePhrase: challengePhrase,
            currentIsUnblockable: currentIsUnblockable
        )
    }

    func disableUnblockableChallenge(
        phrase: String,
        challengePhrase: String,
        currentIsUnblockable: Bool
    ) -> ChallengeDisableResult {
        AppStateChallengeCoordinator.disableUnblockable(
            phrase: phrase,
            challengePhrase: challengePhrase,
            currentIsUnblockable: currentIsUnblockable
        )
    }

    func startPomodoro(
        state: PomodoroEngine.State,
        focusDurationMinutes: Double,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet]
    ) -> PomodoroTransition {
        AppStateFocusFlowCoordinator.startPomodoro(
            state: state,
            focusDurationMinutes: focusDurationMinutes,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets
        )
    }

    func stopPomodoroIfUnlocked(
        state: PomodoroEngine.State,
        isLocked: Bool
    ) -> PomodoroTransition? {
        AppStateFocusFlowCoordinator.stopPomodoroIfUnlocked(
            state: state,
            isLocked: isLocked
        )
    }

    func skipPhaseAction(for status: AppState.PomodoroStatus) -> SkipPhaseAction {
        AppStateFocusFlowCoordinator.skipPhaseAction(for: status)
    }

    func startBreak(
        state: PomodoroEngine.State,
        breakDurationMinutes: Double
    ) -> PomodoroTransition {
        AppStateFocusFlowCoordinator.startBreak(
            state: state,
            breakDurationMinutes: breakDurationMinutes
        )
    }

    func startPause(
        state: PauseEngine.State,
        minutes: Double,
        isBlocking: Bool
    ) -> PauseTransition? {
        AppStateFocusFlowCoordinator.startPause(
            state: state,
            minutes: minutes,
            isBlocking: isBlocking
        )
    }

    func pauseTick(state: PauseEngine.State) -> PauseTickTransition {
        AppStateFocusFlowCoordinator.pauseTick(state: state)
    }

    func cancelPause(state: PauseEngine.State) -> PauseTransition {
        AppStateFocusFlowCoordinator.cancelPause(state: state)
    }

    func pomodoroTickAction(
        status: AppState.PomodoroStatus,
        remaining: TimeInterval
    ) -> PomodoroTickAction {
        AppStateFocusFlowCoordinator.pomodoroTickAction(status: status, remaining: remaining)
    }

    func rebuildForResync(
        calendarIntegrationEnabled: Bool,
        currentSchedules: [Schedule],
        events: [ExternalEvent],
        calendarImportsBlockTime: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        preservedImportedByKey: [String: Schedule]
    ) -> [Schedule]? {
        AppStateCalendarSyncCoordinator.rebuildForResync(
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            currentSchedules: currentSchedules,
            events: events,
            calendarImportsBlockTime: calendarImportsBlockTime,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            preservedImportedByKey: preservedImportedByKey
        )
    }

    func rebuildForScheduleCheck(
        isSynchronizingImportedSchedules: Bool,
        currentSchedules: [Schedule],
        events: [ExternalEvent],
        calendarIntegrationEnabled: Bool,
        calendarImportsBlockTime: Bool,
        suppressedImportedCalendarEventKeys: Set<String>,
        activeRuleSetId: UUID?,
        ruleSets: [RuleSet],
        preservedImportedByKey: [String: Schedule]
    ) -> [Schedule]? {
        AppStateCalendarSyncCoordinator.rebuildForScheduleCheck(
            isSynchronizingImportedSchedules: isSynchronizingImportedSchedules,
            currentSchedules: currentSchedules,
            events: events,
            calendarIntegrationEnabled: calendarIntegrationEnabled,
            calendarImportsBlockTime: calendarImportsBlockTime,
            suppressedImportedCalendarEventKeys: suppressedImportedCalendarEventKeys,
            activeRuleSetId: activeRuleSetId,
            ruleSets: ruleSets,
            preservedImportedByKey: preservedImportedByKey
        )
    }

    func prepareLaunchAtLoginPromptIfNeeded(service: LaunchAtLoginService) -> Bool {
        AppStateLaunchAtLoginCoordinator.preparePromptIfNeeded(
            dependencies: .live(service: service)
        )
    }

    func launchAtLoginStatus(service: LaunchAtLoginService) -> Bool {
        AppStateLaunchAtLoginCoordinator.status(
            dependencies: .live(service: service)
        )
    }

    func enableLaunchAtLogin(service: LaunchAtLoginService) -> Bool {
        AppStateLaunchAtLoginCoordinator.enable(
            dependencies: .live(service: service)
        )
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool, service: LaunchAtLoginService) -> Bool {
        AppStateLaunchAtLoginCoordinator.setEnabled(
            enabled,
            dependencies: .live(service: service)
        )
    }

    func makeRuleContext(
        ruleSets: [RuleSet],
        schedules: [Schedule],
        activeRuleSetId: UUID?,
        pomodoroRuleSetId: UUID?,
        isPomodoroFocus: Bool,
        isBlocking: Bool,
        wasStartedBySchedule: Bool
    ) -> RuleContext {
        RuleContext(
            ruleSets: ruleSets,
            schedules: schedules,
            activeRuleSetId: activeRuleSetId,
            pomodoroRuleSetId: pomodoroRuleSetId,
            isPomodoroFocus: isPomodoroFocus,
            isBlocking: isBlocking,
            wasStartedBySchedule: wasStartedBySchedule
        )
    }

    func currentPrimaryRuleSetId(context: RuleContext) -> UUID? {
        AppStateReadModelCoordinator.currentPrimaryRuleSetId(context: context)
    }

    func currentPrimaryRuleSetName(context: RuleContext) -> String {
        AppStateReadModelCoordinator.currentPrimaryRuleSetName(context: context)
    }

    func allowedRules(context: RuleContext) -> [String] {
        AppStateReadModelCoordinator.allowedRules(context: context)
    }

    func todaySchedules(from schedules: [Schedule]) -> [Schedule] {
        ScheduleEngine.todaySchedules(from: schedules)
    }

    func timeString(time: TimeInterval) -> String {
        AppStateReadModelCoordinator.timeString(time: time)
    }
}
