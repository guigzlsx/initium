import SwiftUI
import SwiftData

struct NowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Activity.scheduledStartAt)
    private var activities: [Activity]

    @StateObject private var viewModel = NowViewModel()
    @State private var stopActivity: Activity?
    @State private var recoveryActivity: Activity?

    private let resolver = DayStateResolver()
    private let consistencyValidator = PersistenceConsistencyValidator()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let transitionActivity = activeTransitionActivity(at: context.date) {
                            transitionContent(for: transitionActivity, now: context.date)
                        } else if let currentActivity = resolver.currentActivity(from: activities, now: context.date) {
                            if consistencyValidator.issues(for: currentActivity).contains(.inProgressActivityHasNoActiveSession) {
                                recoveryContent(for: currentActivity)
                            } else {
                                currentContent(for: currentActivity, now: context.date)
                            }
                        } else {
                            idleContent(now: context.date)
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
                .initiumScreen()
                .navigationTitle("Now")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert("Une action n'a pas pu aboutir", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Une erreur est survenue.")
        }
        .confirmationDialog(
            "Une activité est déjà en cours.",
            isPresented: conflictBinding,
            titleVisibility: .visible
        ) {
            Button("Mettre en pause et commencer") {
                viewModel.resolveStartConflict(
                    with: .pauseAndStart,
                    at: .now,
                    in: modelContext
                )
            }

            Button("Terminer et commencer") {
                viewModel.resolveStartConflict(
                    with: .completeAndStart,
                    at: .now,
                    in: modelContext
                )
            }

            Button("Annuler", role: .cancel) { }
        } message: {
            if let conflict = viewModel.startConflict {
                Text(InitiumLocalization.string("now.conflict.message", conflict.activeActivityTitle))
            }
        }
        .confirmationDialog(
            "Cette activité est toujours indiquée comme en cours.",
            isPresented: recoveryBinding,
            titleVisibility: .visible
        ) {
            Button("Continuer") { recover(.continueActivity) }
            Button("Terminer") { recover(.completeActivity) }
            Button("Corriger", role: .destructive) { recover(.pauseActivity) }
            Button("Annuler", role: .cancel) { recoveryActivity = nil }
        } message: {
            if let recoveryActivity {
                Text(InitiumLocalization.string("recovery.missing_session", recoveryActivity.title))
            }
        }
        .sheet(item: $stopActivity) { activity in
            StopActivitySheet(title: activity.title) { resolution in
                viewModel.resolveStop(
                    resolution,
                    for: activity,
                    at: .now,
                    in: modelContext
                )
                stopActivity = nil
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $viewModel.completionSummary) { summary in
            CompletionSummaryView(summary: summary) {
                viewModel.completionSummary = nil
                appState.selectedTab = .today
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $viewModel.transitionCompletionSummary) { summary in
            TransitionCompletionView(
                summary: summary,
                canStartActivity: canStartActivity(for: summary)
            ) {
                if let activity = activities.first(where: { $0.id == summary.activityID }) {
                    viewModel.startActivityAfterTransition(
                        activity,
                        at: .now,
                        in: modelContext
                    )
                }
                viewModel.transitionCompletionSummary = nil
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func transitionContent(for activity: Activity, now: Date) -> some View {
        let plan = viewModel.transitionPlan(for: activity)
        let state = viewModel.transitionState(for: activity)

        VStack(alignment: .leading, spacing: 20) {
            Text("PRÉPARATION")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(AppTheme.warmAccent)

            Text(activity.title)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(InitiumLocalization.string("now.ready_for", activity.scheduledStartAt.formatted(date: .omitted, time: .shortened)))
                .font(.title3.weight(.semibold))

            if let plan {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Préparation estimée")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        Text(ActivityTiming.durationText(seconds: plan.routineDurationSeconds))
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }

                    if let routine = activity.routine {
                        let calibration = RoutineCalibration().result(for: routine)
                        Text(calibration.hasEnoughHistory
                            ? InitiumLocalization.string("calibration.based_on_sessions", calibration.observationCount)
                            : InitiumLocalization.string("calibration.initial_estimate"))
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }
            }

            if let plan,
               let session = state?.session,
               session.startedAt > plan.transitionStart {
                Text(InitiumLocalization.string("now.preparation_late", plan.transitionStart.formatted(date: .omitted, time: .shortened)))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if let state, let step = state.currentStep {
                transitionStepContent(for: activity, state: state, step: step)
            }
        }
        .initiumCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(InitiumLocalization.string("now.preparation_accessibility", activity.title))
    }

    private func transitionStepContent(
        for activity: Activity,
        state: RoutineExecutionState,
        step: RoutineStep
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(InitiumLocalization.string("now.step_progress", state.currentStepIndex + 1, state.totalStepCount))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(state.progressText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryText)
            }

            InitiumProgressBar(
                progress: Double(state.currentStepIndex) / Double(max(1, state.totalStepCount))
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.title2.weight(.semibold))
                Text(InitiumLocalization.string("duration.approx", ActivityTiming.durationText(seconds: step.estimatedDurationSeconds)))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(InitiumLocalization.string("now.step_accessibility", state.currentStepIndex + 1, state.totalStepCount, step.title))

            Button("Terminé") {
                viewModel.completeTransitionStep(for: activity, at: .now, in: modelContext)
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button("Passer") {
                viewModel.skipTransitionStep(for: activity, at: .now, in: modelContext)
            }
            .buttonStyle(InitiumSecondaryButtonStyle())
            .frame(minHeight: 44)
        }
    }

    private func activeTransitionActivity(at date: Date) -> Activity? {
        activities.first {
            viewModel.transitionStatus(for: $0, at: date) == .active
        }
    }

    private func canStartActivity(for summary: TransitionCompletionSummary) -> Bool {
        let scheduledStart = activities
            .first(where: { $0.id == summary.activityID })?
            .scheduledStartAt ?? .distantFuture
        return scheduledStart <= .now
    }

    @ViewBuilder
    private func currentContent(for activity: Activity, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("NOW")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(AppTheme.accent)

            Text(activity.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Label {
                    Text(activity.scheduledStartAt, format: .dateTime.hour().minute())
                } icon: {
                    Image(systemName: "clock")
                }

                Text("·")
                    .foregroundStyle(AppTheme.secondaryText)

                Text(ActivityTiming.durationText(seconds: activity.estimatedDurationSeconds))
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)

            executionStatus(for: activity, now: now)
            routineContent(for: activity, now: now)
            activityActions(for: activity)
        }
        .initiumCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(InitiumLocalization.string("now.current_accessibility", activity.title))

        if let nextActivity = resolver.nextActivity(from: activities, now: now) {
            nextContent(for: nextActivity)
        }
    }

    @ViewBuilder
    private func executionStatus(for activity: Activity, now: Date) -> some View {
        switch activity.status {
        case .planned:
            VStack(alignment: .leading, spacing: 4) {
                Text(InitiumLocalization.string("now.planned_at", activity.scheduledStartAt.formatted(date: .omitted, time: .shortened)))
                    .font(.title3.weight(.semibold))
                Text("Quand tu es prêt, commence ici.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        case .paused:
            VStack(alignment: .leading, spacing: 4) {
                Text("En pause")
                    .font(.title3.weight(.semibold))
                Text(InitiumLocalization.string("now.elapsed", ActivityTiming.durationText(seconds: ActivityTiming.elapsedSeconds(for: activity, at: now))))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        case .inProgress:
            VStack(alignment: .leading, spacing: 6) {
                if let remaining = ActivityTiming.remainingSeconds(for: activity, at: now), remaining > 0 {
                    Text(ActivityTiming.remainingText(seconds: remaining))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                } else {
                    Text("Le temps prévu est dépassé")
                        .font(.title3.weight(.semibold))
                }

                let elapsed = ActivityTiming.elapsedSeconds(for: activity, at: now)
                if elapsed > activity.estimatedDurationSeconds {
                    Text(InitiumLocalization.string("now.over_by", ActivityTiming.durationText(seconds: elapsed - activity.estimatedDurationSeconds)))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text(InitiumLocalization.string("now.elapsed", ActivityTiming.durationText(seconds: elapsed)))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func routineContent(for activity: Activity, now: Date) -> some View {
        if let state = viewModel.routineState(for: activity), state.totalStepCount > 0 {
            VStack(alignment: .leading, spacing: 14) {
                Divider()

                HStack {
                    Text("ROUTINE")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Text(state.progressText)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.secondaryText)
            .accessibilityLabel(InitiumLocalization.string("now.completed_steps", state.completedStepCount, state.totalStepCount))
                }

                if let step = state.currentStep, activity.status != .paused {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Étape actuelle")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)

                        Text(step.title)
                            .font(.title3.weight(.semibold))

                        Text(InitiumLocalization.string("duration.approx", ActivityTiming.durationText(seconds: step.estimatedDurationSeconds)))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(InitiumLocalization.string("now.step_duration_accessibility", state.currentStepIndex + 1, state.totalStepCount, step.title, ActivityTiming.durationText(seconds: step.estimatedDurationSeconds)))

                    Button("Terminé") {
                        viewModel.completeCurrentStep(for: activity, at: .now, in: modelContext)
                    }
                    .buttonStyle(InitiumPrimaryButtonStyle())
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Button("Passer") {
                        viewModel.skipCurrentStep(for: activity, at: .now, in: modelContext)
                    }
                    .buttonStyle(InitiumSecondaryButtonStyle())
                    .frame(minHeight: 44)
                } else if state.isFinished {
                    Label("Routine terminée", systemImage: "checkmark.circle")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Text("Routine en pause")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func activityActions(for activity: Activity) -> some View {
        switch activity.status {
        case .planned:
            Button("Commencer") {
                viewModel.requestStart(activity: activity, at: .now, in: modelContext)
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        case .inProgress:
            pauseButton(for: activity)

            secondaryActions(for: activity)
        case .paused:
            Button("Reprendre") {
                viewModel.resume(activity: activity, at: .now, in: modelContext)
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            secondaryActions(for: activity)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func pauseButton(for activity: Activity) -> some View {
        Button("Pause") {
            viewModel.pause(activity: activity, at: .now, in: modelContext)
        }
        .modifier(ExecutionButtonModifier(isSecondary: viewModel.routineState(for: activity)?.currentStep != nil))
    }

    private func secondaryActions(for activity: Activity) -> some View {
        HStack(spacing: 10) {
            Button("+5 min") {
                viewModel.addFiveMinutes(to: activity, in: modelContext)
            }
            .buttonStyle(InitiumSecondaryButtonStyle())

            Button("Terminer") {
                viewModel.complete(activity: activity, at: .now, in: modelContext)
            }
            .buttonStyle(InitiumSecondaryButtonStyle())

            Button("Arrêter") {
                stopActivity = activity
            }
            .buttonStyle(InitiumSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
    }

    private func idleContent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "pause.circle")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)

            Text("Rien en cours.")
                .font(.title2.weight(.semibold))

            if let nextActivity = resolver.nextActivity(from: activities, now: now) {
                Text("Ta prochaine activité est :")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(InitiumLocalization.string("now.next_activity", nextActivity.title, nextActivity.scheduledStartAt.formatted(date: .omitted, time: .shortened)))
                    .font(.title3.weight(.semibold))

                Button("Voir Today") {
                    appState.selectedTab = .today
                }
                .buttonStyle(InitiumSecondaryButtonStyle())
            } else {
                Text("Rien pour l'instant. Profite du moment.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .initiumCard()
        .accessibilityElement(children: .combine)
    }

    private func recoveryContent(for activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "arrow.clockwise.circle")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.warmAccent)

            Text("Cette activité est toujours indiquée comme en cours.")
                .font(.title2.weight(.semibold))

            Text(activity.title)
                .font(.title3.weight(.medium))

            Text("Choisis comment reprendre cette session.")
                .foregroundStyle(AppTheme.secondaryText)

            Button("Choisir") {
                recoveryActivity = activity
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
        }
        .initiumCard()
        .accessibilityElement(children: .combine)
    }

    private func nextContent(for activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ENSUITE")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.secondaryText)

            Text(activity.title)
                .font(.body.weight(.medium))

            Text(activity.scheduledStartAt, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.secondaryText)
        }
        .initiumCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(InitiumLocalization.string("now.next_accessibility", activity.title, activity.scheduledStartAt.formatted(date: .omitted, time: .shortened)))
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var conflictBinding: Binding<Bool> {
        Binding(
            get: { viewModel.startConflict != nil },
            set: { if !$0 { viewModel.startConflict = nil } }
        )
    }

    private var recoveryBinding: Binding<Bool> {
        Binding(
            get: { recoveryActivity != nil },
            set: { if !$0 { recoveryActivity = nil } }
        )
    }

    private func recover(_ action: ExecutionRecoveryAction) {
        guard let recoveryActivity else { return }

        do {
            try ExecutionRecoveryService().recover(
                activity: recoveryActivity,
                using: action,
                at: .now,
                in: modelContext
            )
            self.recoveryActivity = nil
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

private struct ExecutionButtonModifier: ViewModifier {
    let isSecondary: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSecondary {
            content
                .buttonStyle(InitiumSecondaryButtonStyle())
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        } else {
            content
                .buttonStyle(InitiumPrimaryButtonStyle())
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct StopActivitySheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onResolve: (StopActivityResolution) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Arrêter cette activité ?")
                    .font(.title2.weight(.bold))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Tu peux choisir la suite, sans que cela signifie que la session est ratée.")
                    .foregroundStyle(AppTheme.secondaryText)

                VStack(spacing: 10) {
                    actionButton("Terminer", resolution: .complete, prominent: true)
                    actionButton("Reporter", resolution: .postpone, prominent: false)
                    actionButton("Ignorer", resolution: .skip, prominent: false)
                    actionButton("Annuler", resolution: .cancel, prominent: false)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Choisir la suite")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func actionButton(
        _ title: String,
        resolution: StopActivityResolution,
        prominent: Bool
    ) -> some View {
        if prominent {
            Button(title) {
                onResolve(resolution)
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        } else {
            Button(title) {
                onResolve(resolution)
                if resolution == .cancel {
                    dismiss()
                }
            }
            .buttonStyle(InitiumSecondaryButtonStyle())
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
    }
}

private struct CompletionSummaryView: View {
    @Environment(\.dismiss) private var dismiss

    let summary: ActivityCompletionSummary
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Terminé", systemImage: "checkmark.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.accent)

            Text(summary.title)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(InitiumLocalization.string("summary.planned", ActivityTiming.durationText(seconds: summary.estimatedDurationSeconds)))
                Text(InitiumLocalization.string("summary.actual", ActivityTiming.durationText(seconds: summary.actualDurationSeconds)))
            }
            .foregroundStyle(AppTheme.secondaryText)

            Button("Voir la suite") {
                onContinue()
                dismiss()
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)

            Spacer()
        }
        .padding(24)
    }
}

private struct TransitionCompletionView: View {
    @Environment(\.dismiss) private var dismiss

    let summary: TransitionCompletionSummary
    let canStartActivity: Bool
    let onStartActivity: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Tu es prêt", systemImage: "checkmark.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.warmAccent)

            Text(summary.title)
                .font(.title3.weight(.semibold))

            if summary.minutesDifference > 0 {
                Text(InitiumLocalization.string("summary.ready_early", summary.minutesDifference))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("Préparation terminée.")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text(InitiumLocalization.string("summary.actual_duration", ActivityTiming.durationText(seconds: summary.actualDurationSeconds)))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            if canStartActivity {
                Button("Commencer l'activité") {
                    onStartActivity()
                    dismiss()
                }
                .buttonStyle(InitiumPrimaryButtonStyle())
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            } else {
                Text("Tout est prêt pour l'instant.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()
        }
        .padding(24)
        .initiumScreen()
    }
}

#Preview("Now") {
    NowView()
        .environmentObject(AppState())
        .modelContainer(PersistenceController.preview)
}
