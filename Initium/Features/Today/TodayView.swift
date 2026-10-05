import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Activity.scheduledStartAt)
    private var activities: [Activity]

    @State private var selectedDate = Date.now
    @State private var showingActivityEditor = false
    @State private var editingActivity: Activity?
    @State private var errorMessage: String?
    @State private var pendingTransitionActivity: Activity?
    @State private var transitionConflictActivity: Activity?
    @State private var showingTransitionConflict = false
    @State private var showingReplan = false
    @State private var showingSettings = false
    @State private var replanFrom = Date.now

    private let resolver = DayStateResolver()
    private let calendar = Calendar.current
    private let transitionPlanner = TransitionPlanner()
    private let routineCalibration = RoutineCalibration()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            navigationContent(now: context.date)
        }
    }

    private func navigationContent(now: Date) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(now: now)
                    nowSection(now: now)

                    if shouldSuggestReplan(at: now) {
                        replanPrompt(at: now)
                    }

                    if let nextActivity = nextActivity(at: now) {
                        nextSection(activity: nextActivity, now: now)
                    }

                    timeline(now: now)
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .initiumScreen()
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
            .onAppear {
                if appState.launchEditorDemo,
                   let demoActivity = dayActivities.first(where: { $0.title == "Restaurant" }) {
                    editingActivity = demoActivity
                    showingActivityEditor = true
                    appState.launchEditorDemo = false
                } else if appState.launchReplanDemo {
                    openReplan(at: now)
                    appState.launchReplanDemo = false
                }
            }
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        changeDay(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Jour précédent")

                    if !calendar.isDateInToday(selectedDate) {
                        Button("Aujourd'hui") {
                            selectedDate = .now
                        }
                    }

                    Button {
                        changeDay(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Jour suivant")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if canOpenReplan {
                            Menu {
                                Button {
                                    openReplan(at: .now)
                                } label: {
                                    Label("Réorganiser la journée", systemImage: "arrow.trianglehead.2.clockwise")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                            }
                            .accessibilityLabel("Actions de la journée")
                        }

                        Button {
                            editingActivity = nil
                            showingActivityEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Ajouter une activité")

                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Réglages")
                    }
                }
            }
            .sheet(isPresented: $showingActivityEditor, onDismiss: {
                editingActivity = nil
            }) {
                ActivityEditorView(activity: editingActivity, day: selectedDate)
            }
            .sheet(isPresented: $showingReplan) {
                ReplanView(
                    activities: dayActivities,
                    replanFrom: replanFrom
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("Impossible de démarrer", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Une erreur est survenue.")
            }
            .confirmationDialog(
                "La préparation peut commencer.",
                isPresented: $showingTransitionConflict,
                titleVisibility: .visible
            ) {
                Button("Mettre en pause et commencer") {
                    pauseCurrentActivityAndStartTransition(at: now)
                }

                Button("+5 min puis continuer") {
                    extendCurrentActivity(by: 300, at: now)
                }

                Button("+10 min puis continuer") {
                    extendCurrentActivity(by: 600, at: now)
                }

                Button("Annuler", role: .cancel) { }
            } message: {
                if let current = transitionConflictActivity,
                   let pending = pendingTransitionActivity {
                    Text(InitiumLocalization.string("today.transition.conflict.message", current.title, pending.title))
                }
            }
        }
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting(for: now))
                .font(.largeTitle.weight(.bold))

            Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func nowSection(now: Date) -> some View {
        if let currentActivity = currentActivity(at: now) {
            nowCard(for: currentActivity, now: now)
        } else {
            idleNowCard(next: nextActivity(at: now))
        }
    }

    private func nowCard(for activity: Activity, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOW")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(AppTheme.accent)

            Text(activity.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 14) {
                Label {
                    Text(activity.scheduledStartAt, format: .dateTime.hour().minute())
                } icon: {
                    Image(systemName: "clock")
                }

                Text("→")
                    .foregroundStyle(AppTheme.secondaryText)

                Text(activity.scheduledStartAt.addingTimeInterval(TimeInterval(activity.estimatedDurationSeconds)), format: .dateTime.hour().minute())
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)

            if let remaining = ActivityTiming.remainingSeconds(for: activity, at: now) {
                Text(ActivityTiming.remainingText(seconds: remaining))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .monospacedDigit()
            } else {
                Text(InitiumLocalization.string("today.planned_at", activity.scheduledStartAt.formatted(date: .omitted, time: .shortened)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Button {
                if activity.status == .planned {
                    start(activity)
                } else {
                    appState.selectedTab = .now
                }
            } label: {
                Text(activity.status == .planned ? "Commencer" : "Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .controlSize(.large)
        }
        .initiumCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(InitiumLocalization.string("today.now.accessibility", activity.title))
    }

    private func idleNowCard(next: Activity?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOW")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(AppTheme.secondaryText)

            Text("Rien pour l'instant.")
                .font(.title3.weight(.semibold))

            if let next {
                Text(InitiumLocalization.string("today.next_activity", next.title, next.scheduledStartAt.formatted(date: .omitted, time: .shortened)))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("Ta journée peut rester ouverte.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .initiumCard()
        .accessibilityElement(children: .combine)
    }

    private func replanPrompt(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ta journée a changé.")
                .font(.headline)

            Text("On peut ajuster la suite à partir de maintenant.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            Button("Réorganiser") {
                openReplan(at: date)
            }
            .buttonStyle(InitiumSecondaryButtonStyle())
            .frame(minHeight: 44)
        }
        .initiumCard()
        .accessibilityElement(children: .contain)
    }

    private func nextSection(activity: Activity, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEXT")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(AppTheme.secondaryText)

            Button {
                edit(activity)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text(activity.scheduledStartAt, format: .dateTime.hour().minute())
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(AppTheme.secondaryText)

                        if let calibration = routineCalibration(for: activity) {
                            Text(InitiumLocalization.string("today.preparation_approx", ActivityTiming.durationText(seconds: calibration.recommendedDurationSeconds)))
                                .font(.caption)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                    }

                    Spacer()

                    if calendar.isDateInToday(selectedDate) {
                        Text(relativeTime(from: now, to: activity.scheduledStartAt))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            transitionSummary(for: activity, now: now)
        }
        .initiumCard()
    }

    @ViewBuilder
    private func transitionSummary(for activity: Activity, now: Date) -> some View {
        if let plan = transitionPlanner.makePlan(for: activity) {
            switch transitionPlanner.state(for: activity, now: now) {
            case .upcoming:
                Text(InitiumLocalization.string("today.preparation_at", plan.transitionStart.formatted(date: .omitted, time: .shortened), ActivityTiming.durationText(seconds: plan.routineDurationSeconds)))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            case .ready:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Il est temps de te préparer.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.warmAccent)

                    Button("Commencer") {
                        requestTransitionStart(for: activity, at: now)
                    }
                    .buttonStyle(InitiumPrimaryButtonStyle())
                    .frame(minHeight: 44)
                }
            case .active:
                Button("Voir la préparation") {
                    appState.selectedTab = .now
                }
                .buttonStyle(InitiumSecondaryButtonStyle())
                .frame(minHeight: 44)
            case .missed:
                VStack(alignment: .leading, spacing: 8) {
                    Text(InitiumLocalization.string("today.preparation_missed", plan.transitionStart.formatted(date: .omitted, time: .shortened)))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)

                    Button("Commencer maintenant") {
                        requestTransitionStart(for: activity, at: now)
                    }
                    .buttonStyle(InitiumSecondaryButtonStyle())
                    .frame(minHeight: 44)
                }
            case .completed:
                Text("Préparation terminée")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            case .none:
                EmptyView()
            }
        }
    }

    private func timeline(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(AppTheme.secondaryText)

            if dayActivities.isEmpty {
                emptyState
            } else {
                ForEach(dayActivities) { activity in
                    Button {
                        edit(activity)
                    } label: {
                        ActivityTimelineRow(
                            activity: activity,
                            isCurrent: activity.id == currentActivity(at: now)?.id
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
        }
        .initiumCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sun.max")
                .font(.title2)
                .foregroundStyle(AppTheme.warmAccent)

            Text("Ta journée est libre.")
                .font(.headline)

            Text("Ajoute quelque chose quand tu en as besoin.")
                .foregroundStyle(AppTheme.secondaryText)

            Button("Ajouter une activité") {
                editingActivity = nil
                showingActivityEditor = true
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
        }
    }

    private var dayActivities: [Activity] {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        return activities.filter {
            $0.scheduledStartAt >= start && $0.scheduledStartAt < end
        }
    }

    private func routineCalibration(for activity: Activity) -> RoutineCalibrationResult? {
        guard let routine = activity.routine else { return nil }
        let result = routineCalibration.result(for: routine)
        return result.hasEnoughHistory ? result : nil
    }

    private func currentActivity(at now: Date) -> Activity? {
        guard calendar.isDate(selectedDate, inSameDayAs: now) else {
            return nil
        }

        return resolver.currentActivity(from: dayActivities, now: now)
    }

    private func nextActivity(at now: Date) -> Activity? {
        if calendar.isDate(selectedDate, inSameDayAs: now) {
            return resolver.nextActivity(from: dayActivities, now: now)
        }

        return dayActivities.first(where: { !isTerminal($0.status) })
    }

    private func start(_ activity: Activity) {
        do {
            try ActivityExecutionService().start(
                activity: activity,
                at: .now,
                in: modelContext
            )
            appState.selectedTab = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestTransitionStart(for activity: Activity, at date: Date) {
        if let current = currentActivity(at: date),
           current.id != activity.id,
           current.status == .inProgress {
            pendingTransitionActivity = activity
            transitionConflictActivity = current
            showingTransitionConflict = true
            return
        }

        startTransition(activity, at: date)
    }

    private func startTransition(_ activity: Activity, at date: Date) {
        do {
            try TransitionExecutionService().start(
                activity: activity,
                at: date,
                in: modelContext
            )
            appState.selectedTab = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pauseCurrentActivityAndStartTransition(at date: Date) {
        guard let current = transitionConflictActivity,
              let pending = pendingTransitionActivity else {
            return
        }

        do {
            try ActivityExecutionService().pause(
                activity: current,
                at: date,
                in: modelContext
            )
            startTransition(pending, at: date)
        } catch {
            errorMessage = error.localizedDescription
        }

        clearTransitionConflict()
    }

    private func extendCurrentActivity(by seconds: Int, at date: Date) {
        guard let current = transitionConflictActivity else {
            return
        }

        do {
            try ActivityExecutionService().addTime(
                to: current,
                seconds: seconds,
                in: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        clearTransitionConflict()
    }

    private func clearTransitionConflict() {
        pendingTransitionActivity = nil
        transitionConflictActivity = nil
        showingTransitionConflict = false
    }

    private var canOpenReplan: Bool {
        calendar.isDateInToday(selectedDate) &&
            dayActivities.contains { !isTerminal($0.status) } &&
            dayActivities.count > 1
    }

    private func shouldSuggestReplan(at date: Date) -> Bool {
        guard canOpenReplan else { return false }

        if let current = currentActivity(at: date), current.status == .inProgress {
            let elapsed = ActivityTiming.elapsedSeconds(for: current, at: date)
            return elapsed > current.estimatedDurationSeconds && nextActivity(at: date) != nil
        }

        return dayActivities.contains { activity in
            guard activity.status == .completed,
                  let completedAt = activity.completedAt else {
                return false
            }

            let expectedEnd = activity.scheduledStartAt.addingTimeInterval(
                TimeInterval(activity.estimatedDurationSeconds)
            )
            return completedAt > expectedEnd && completedAt <= date
        } && nextActivity(at: date) != nil
    }

    private func openReplan(at date: Date) {
        replanFrom = date
        showingReplan = true
    }

    private func edit(_ activity: Activity) {
        editingActivity = activity
        showingActivityEditor = true
    }

    private func changeDay(by value: Int) {
        selectedDate = calendar.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
    }

    private func greeting(for date: Date) -> String {
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return InitiumLocalization.string("Bonjour")
        case 12..<18:
            return InitiumLocalization.string("Bon après-midi")
        default:
            return InitiumLocalization.string("Bonsoir")
        }
    }

    private func relativeTime(from now: Date, to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let minutes = seconds / 60

        if minutes < 1 {
            return InitiumLocalization.string("today.soon")
        }

        if minutes < 60 {
            return InitiumLocalization.string("today.in_minutes", minutes)
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0
            ? InitiumLocalization.string("today.in_hours", hours)
            : InitiumLocalization.string("today.in_hours_minutes", hours, remainingMinutes)
    }

    private func isTerminal(_ status: ActivityStatus) -> Bool {
        switch status {
        case .completed, .skipped, .cancelled, .postponed:
            return true
        case .planned, .inProgress, .paused:
            return false
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

private struct ActivityTimelineRow: View {
    let activity: Activity
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(activity.scheduledStartAt, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isCurrent ? AppTheme.accent : AppTheme.secondaryText)
                .frame(width: 54, alignment: .leading)

            Capsule()
                .fill(isCurrent ? AppTheme.accent : Color.secondary.opacity(0.30))
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if activity.status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Text(activity.title)
                        .font(.body.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(activity.status == .completed ? AppTheme.secondaryText : AppTheme.primaryText)
                        .strikethrough(activity.status == .completed)
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                if let routine = activity.routine {
                    let calibration = RoutineCalibration().result(for: routine)
                    if calibration.hasEnoughHistory {
                        Text(InitiumLocalization.string("today.preparation_approx", ActivityTiming.durationText(seconds: calibration.recommendedDurationSeconds)))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.mutedText)
                    }
                }
            }

            Spacer()

            Text(ActivityTiming.durationText(seconds: activity.estimatedDurationSeconds))
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(InitiumLocalization.string("today.timeline.accessibility", activity.title, activity.scheduledStartAt.formatted(date: .omitted, time: .shortened), statusText))
    }

    private var statusText: String {
        switch activity.status {
        case .planned:
            return isCurrent ? "Maintenant" : "À venir"
        case .inProgress:
            return InitiumLocalization.string("En cours")
        case .paused:
            return InitiumLocalization.string("En pause")
        case .completed:
            return InitiumLocalization.string("Terminée")
        case .skipped:
            return InitiumLocalization.string("Ignorée")
        case .postponed:
            return InitiumLocalization.string("Reportée")
        case .cancelled:
            return InitiumLocalization.string("Annulée")
        }
    }
}

#Preview("Today") {
    TodayView()
        .environmentObject(AppState())
        .modelContainer(PersistenceController.preview)
}
