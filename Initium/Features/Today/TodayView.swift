import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var templateCatalog: RoutineTemplateCatalogViewModel
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
    @State private var applyingTemplateActivityID: UUID?

    private let resolver = DayStateResolver()
    private let calendar = Calendar.current
    private let transitionPlanner = TransitionPlanner()
    private let routineCalibration = RoutineCalibration()

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                navigationContent(now: context.date)
                    #if DEBUG
                    .onAppear {
                        if appState.launchEditorDemo,
                           let demoActivity = dayActivities.first(where: { $0.title == "Restaurant" }) {
                            editingActivity = demoActivity
                            showingActivityEditor = true
                            appState.launchEditorDemo = false
                        } else if appState.launchReplanDemo {
                            openReplan(at: context.date)
                            appState.launchReplanDemo = false
                        }
                    }
                    #endif
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
                            pauseCurrentActivityAndStartTransition(at: context.date)
                        }

                        Button("+5 min puis continuer") {
                            extendCurrentActivity(by: 300, at: context.date)
                        }

                        Button("+10 min puis continuer") {
                            extendCurrentActivity(by: 600, at: context.date)
                        }

                        Button("Annuler", role: .cancel) { }
                    } message: {
                        if let current = transitionConflictActivity,
                           let pending = pendingTransitionActivity {
                            Text(InitiumLocalization.string("today.transition.conflict.message", current.title, pending.title))
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func navigationContent(now: Date) -> some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: InitiumSpacing.lg) {
                    topControls
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
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, InitiumSpacing.sm)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var topControls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                compactIconButton("chevron.left", label: "Jour précédent") {
                    changeDay(by: -1)
                }

                if !calendar.isDateInToday(selectedDate) {
                    Button("Aujourd'hui") {
                        selectedDate = .now
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(AppTheme.surfaceElevated, in: Capsule())
                    .overlay { Capsule().stroke(AppTheme.border, lineWidth: 1) }
                }

                compactIconButton("chevron.right", label: "Jour suivant") {
                    changeDay(by: 1)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if canOpenReplan {
                    Menu {
                        Button {
                            openReplan(at: .now)
                        } label: {
                            Label("Réorganiser la journée", systemImage: "arrow.trianglehead.2.clockwise")
                        }
                    } label: {
                        topControlIcon("ellipsis", label: "Actions de la journée")
                    }
                }

                compactIconButton("plus", label: "Ajouter une activité") {
                    editingActivity = nil
                    showingActivityEditor = true
                }

                compactIconButton("gearshape", label: "Réglages") {
                    showingSettings = true
                }
            }
        }
    }

    private func compactIconButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            topControlIcon(systemName, label: label)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func topControlIcon(_ systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.primaryText)
            .frame(width: 44, height: 44)
            .background(AppTheme.surfaceElevated, in: Circle())
            .overlay { Circle().stroke(AppTheme.border, lineWidth: 1) }
            .accessibilityLabel(label)
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY")
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.accent)

            Text("Today")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(AppTheme.Typography.secondary)
                .foregroundStyle(AppTheme.secondaryText)

            Text(greeting(for: now))
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.mutedText)
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
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.accent)

            Text(activity.title)
                .font(AppTheme.Typography.cardTitle)
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
                InitiumRemainingMetric(seconds: remaining)
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
        .initiumCard(padding: 26)
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
        VStack(alignment: .leading, spacing: InitiumSpacing.md) {
            Text("NEXT")
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.secondaryText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: InitiumSpacing.sm) {
                    nextCard(activity: activity, now: now)
                    rhythmCard(for: activity)
                }
                VStack(spacing: InitiumSpacing.sm) {
                    nextCard(activity: activity, now: now)
                    rhythmCard(for: activity)
                }
            }

            transitionSummary(for: activity, now: now)
        }
        .initiumCard(padding: 18)
    }

    private func nextCard(activity: Activity, now: Date) -> some View {
        Button {
            edit(activity)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(activity.scheduledStartAt, format: .dateTime.hour().minute())
                    .font(AppTheme.Typography.metricLarge)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)

                Text(activity.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)

                if calendar.isDateInToday(selectedDate) {
                    Text(relativeTime(from: now, to: activity.scheduledStartAt))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(18)
            .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: InitiumRadius.large))
        }
        .buttonStyle(.plain)
    }

    private func rhythmCard(for activity: Activity) -> some View {
        let calibration = routineCalibration(for: activity)

        return VStack(alignment: .leading, spacing: 8) {
            Text("RHYTHM")
                .font(AppTheme.Typography.caption)
                .tracking(1.5)
                .foregroundStyle(AppTheme.mutedText)

            Text(calibration.map { ActivityTiming.durationText(seconds: $0.recommendedDurationSeconds) } ?? "—")
                .font(AppTheme.Typography.metricLarge)
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)

            Text(LocalizedStringKey(calibration == nil ? "Pas encore calibré" : "habituellement"))
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(18)
        .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: InitiumRadius.large))
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
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.secondaryText)

            if dayActivities.isEmpty {
                emptyState
            } else {
                ForEach(dayActivities) { activity in
                    VStack(alignment: .leading, spacing: 10) {
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

                        if let match = templateSuggestion(for: activity) {
                            RoutineTemplateSuggestionCard(
                                match: match,
                                catalog: templateCatalog.catalog,
                                isApplying: applyingTemplateActivityID == activity.id
                            ) {
                                applyTemplate(match, to: activity)
                            }
                        }
                    }
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

    private func templateSuggestion(for activity: Activity) -> RoutineTemplateMatch? {
        guard !isTerminal(activity.status) else { return nil }
        return templateCatalog.match(for: activity)
    }

    private func applyTemplate(_ match: RoutineTemplateMatch, to activity: Activity) {
        applyingTemplateActivityID = activity.id

        Task { @MainActor in
            defer { applyingTemplateActivityID = nil }

            do {
                _ = try await RoutineTemplateApplicationService().apply(
                    template: match.template,
                    catalog: templateCatalog.catalog,
                    to: activity,
                    in: modelContext
                )
                InitiumHaptics.success()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
            InitiumHaptics.selection()
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
            InitiumHaptics.selection()
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
            Group {
                if activity.externalIsAllDay {
                    Text(LocalizedStringKey("calendar.all_day"))
                } else {
                    Text(activity.scheduledStartAt, format: .dateTime.hour().minute())
                }
            }
                .font(activity.externalIsAllDay ? .caption.weight(.semibold) : .body.weight(.semibold).monospacedDigit())
                .foregroundStyle(isCurrent ? AppTheme.accent : AppTheme.secondaryText)
                .frame(width: activity.externalIsAllDay ? 72 : 54, alignment: .leading)

            Capsule()
                .fill(isCurrent ? AppTheme.accent : AppTheme.border)
                .frame(width: 4, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if activity.status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Text(activity.title)
                        .font(.body.weight(isCurrent ? .semibold : .medium))
                        .foregroundStyle(activity.status == .completed ? AppTheme.secondaryText : AppTheme.primaryText)
                        .strikethrough(activity.status == .completed)
                }

                if activity.isCalendarActivity {
                    Label(LocalizedStringKey("calendar.source_badge"), systemImage: "calendar")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.mutedText)
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
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(isCurrent ? AppTheme.surfaceElevated : Color.clear, in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
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
        .environmentObject(RoutineTemplateCatalogViewModel())
        .modelContainer(PersistenceController.preview)
}
