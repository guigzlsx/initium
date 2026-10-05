import SwiftUI
import SwiftData

private enum ReplanConflictChoice: String, CaseIterable, Identifiable {
    case postpone
    case shorten
    case keep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .postpone:
            return InitiumLocalization.string("replan.postpone_tomorrow")
        case .shorten:
            return InitiumLocalization.string("replan.shorten")
        case .keep:
            return InitiumLocalization.string("replan.keep")
        }
    }
}

struct ReplanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let activities: [Activity]
    let replanFrom: Date

    @State private var proposal: ReplanProposal?
    @State private var conflictChoices: [UUID: ReplanConflictChoice] = [:]
    @State private var reducedDurations: [UUID: Int] = [:]
    @State private var postponedDates: [UUID: Date] = [:]
    @State private var undoSnapshot: ReplanUndoSnapshot?
    @State private var didApply = false
    @State private var errorMessage: String?

    private let replanner = ScheduleReplanner()

    init(activities: [Activity], replanFrom: Date) {
        self.activities = activities
        self.replanFrom = replanFrom
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding()
            }
            .scrollIndicators(.hidden)
            .initiumScreen()
            .navigationTitle("Réorganiser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }

                if let proposal, proposal.hasChanges, !didApply {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Appliquer") {
                            applyProposal(proposal)
                        }
                    }
                }
            }
            .alert("Impossible d'appliquer ces changements", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Une erreur est survenue.")
            }
            .onAppear {
                prepareProposal()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if didApply {
            appliedContent
        } else if let proposal {
            proposalContent(proposal)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    private var appliedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Plan mis à jour", systemImage: "checkmark.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.accent)

            Text("La suite de ta journée reflète maintenant la réalité.")
                .foregroundStyle(AppTheme.secondaryText)

            if undoSnapshot != nil {
                Button("Annuler les changements") {
                    undoLastChange()
                }
                .buttonStyle(InitiumSecondaryButtonStyle())
                .frame(maxWidth: .infinity, minHeight: 44)
            }

            Button("Terminé") {
                dismiss()
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .controlSize(.large)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .initiumCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func proposalContent(_ proposal: ReplanProposal) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(proposal.hasChanges ? "Ta journée a changé." : "Tout tient encore dans ta journée.")
                    .font(.largeTitle.weight(.bold))

                Text(
                    proposal.hasChanges
                        ? "On peut ajuster la suite à partir de " + formattedTime(replanFrom) + "."
                        : "Aucun changement n'est nécessaire pour le moment."
                )
                .foregroundStyle(AppTheme.secondaryText)
            }
            .initiumCard()

            if proposal.hasChanges {
                changeList(proposal)
            } else {
                Button("Fermer") {
                    dismiss()
                }
                .buttonStyle(InitiumPrimaryButtonStyle())
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private func changeList(_ proposal: ReplanProposal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NOUVEAU PLAN")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(AppTheme.secondaryText)

            ForEach(visibleChanges(from: proposal)) { change in
                changeRow(change, conflict: proposal.conflicts.first { $0.activityID == change.activityID })
            }

            ForEach(proposal.conflicts) { conflict in
                conflictRow(conflict)
            }
        }
        .initiumCard()
    }

    private func changeRow(_ change: ReplanChange, conflict: ReplanConflict?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(change.title)
                    .font(.headline)
                Spacer()
                if change.isFixedTime {
                    Text("Horaire fixe")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            if conflict != nil {
                Text("Une décision est nécessaire")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.warmAccent)
            } else if change.action == .shifted {
                Text(InitiumLocalization.string("replan.shifted_time", formattedTime(change.originalStart), formattedTime(change.proposedStart)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryText)
            } else if change.isFixedTime {
                Text(InitiumLocalization.string("replan.unchanged_time", formattedTime(change.originalStart)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription(for: change, conflict: conflict))
    }

    private func conflictRow(_ conflict: ReplanConflict) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text(InitiumLocalization.string("replan.conflict", conflict.fixedActivityTitle ?? InitiumLocalization.string("replan.end_of_day")))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)

            Picker(
                "Choix pour " + conflict.title,
                selection: choiceBinding(for: conflict.id)
            ) {
                ForEach(availableChoices(for: conflict)) { choice in
                    Text(choice.title).tag(choice)
                }
            }

            if conflictChoice(for: conflict) == .shorten,
               !conflict.suggestedDurationsSeconds.isEmpty {
                Picker(
                    "Durée de " + conflict.title,
                    selection: reducedDurationBinding(for: conflict)
                ) {
                    ForEach(conflict.suggestedDurationsSeconds, id: \.self) { duration in
                        Text(ActivityTiming.durationText(seconds: duration))
                        .tag(duration)
                    }
                }
            } else if conflictChoice(for: conflict) == .postpone {
                DatePicker(
                    "Reporter à",
                    selection: postponedDateBinding(for: conflict),
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func visibleChanges(from proposal: ReplanProposal) -> [ReplanChange] {
        let conflictIDs = Set(proposal.conflicts.map(\.activityID))
        return proposal.changes.filter {
            $0.action != .unchanged || $0.isFixedTime || conflictIDs.contains($0.activityID)
        }
    }

    private func availableChoices(for conflict: ReplanConflict) -> [ReplanConflictChoice] {
        if conflict.suggestedDurationsSeconds.isEmpty {
            return [.postpone, .keep]
        }
        return ReplanConflictChoice.allCases
    }

    private func conflictChoice(for conflict: ReplanConflict) -> ReplanConflictChoice {
        conflictChoices[conflict.id] ?? .postpone
    }

    private func choiceBinding(for id: UUID) -> Binding<ReplanConflictChoice> {
        Binding(
            get: { conflictChoices[id] ?? .postpone },
            set: { conflictChoices[id] = $0 }
        )
    }

    private func reducedDurationBinding(for conflict: ReplanConflict) -> Binding<Int> {
        Binding(
            get: {
                reducedDurations[conflict.id] ?? conflict.suggestedDurationsSeconds.first ?? 15 * 60
            },
            set: { reducedDurations[conflict.id] = $0 }
        )
    }

    private func postponedDateBinding(for conflict: ReplanConflict) -> Binding<Date> {
        Binding(
            get: {
                postponedDates[conflict.id] ?? tomorrowMorning(for: conflict.originalStart)
            },
            set: { postponedDates[conflict.id] = $0 }
        )
    }

    private func prepareProposal() {
        let nextProposal = replanner.makeProposal(
            activities: activities,
            replanFrom: replanFrom
        )
        proposal = nextProposal
        conflictChoices = Dictionary(
            uniqueKeysWithValues: nextProposal.conflicts.map { ($0.id, .postpone) }
        )
        reducedDurations = Dictionary(
            uniqueKeysWithValues: nextProposal.conflicts.compactMap { conflict in
                guard let duration = conflict.suggestedDurationsSeconds.first else { return nil }
                return (conflict.id, duration)
            }
        )
        postponedDates = Dictionary(
            uniqueKeysWithValues: nextProposal.conflicts.map {
                ($0.id, tomorrowMorning(for: $0.originalStart))
            }
        )
    }

    private func applyProposal(_ proposal: ReplanProposal) {
        let resolutions = Dictionary(
            uniqueKeysWithValues: proposal.conflicts.map { conflict in
                (conflict.id, resolution(for: conflict))
            }
        )

        do {
            undoSnapshot = try ReplanPersistenceService().apply(
                proposal: proposal,
                resolutions: resolutions,
                in: modelContext
            )
            didApply = true
            updateTransitionNotifications(for: proposal, resolutions: resolutions)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolution(for conflict: ReplanConflict) -> ReplanConflictResolution {
        switch conflictChoice(for: conflict) {
        case .postpone:
            return .postpone(
                to: postponedDates[conflict.id] ?? tomorrowMorning(for: conflict.originalStart)
            )
        case .shorten:
            return .shorten(
                toSeconds: reducedDurations[conflict.id]
                    ?? conflict.suggestedDurationsSeconds.first
                    ?? 15 * 60
            )
        case .keep:
            return .keep
        }
    }

    private func updateTransitionNotifications(
        for proposal: ReplanProposal,
        resolutions: [UUID: ReplanConflictResolution]
    ) {
        let affectedIDs = Set(
            proposal.changes
                .filter { $0.action != .unchanged || resolutions[$0.id] != nil }
                .map(\.activityID)
        )
        refreshTransitionNotifications(
            for: activities.filter { affectedIDs.contains($0.id) }
        )
    }

    private func refreshTransitionNotifications(for affectedActivities: [Activity]) {

        Task { @MainActor in
            let scheduler = LocalNotificationScheduler()
            guard await scheduler.isAuthorized() else { return }

            for activity in affectedActivities {
                if activity.status == .completed ||
                    activity.status == .skipped ||
                    activity.status == .cancelled ||
                    activity.status == .postponed {
                    scheduler.remove(for: activity)
                } else if let plan = TransitionPlanner().makePlan(for: activity) {
                    try? await scheduler.schedule(for: activity, plan: plan)
                } else {
                    scheduler.remove(for: activity)
                }
            }
        }
    }

    private func undoLastChange() {
        guard let undoSnapshot else { return }
        let affectedIDs = Set(undoSnapshot.activities.map(\.activityID))

        do {
            try ReplanPersistenceService().undo(snapshot: undoSnapshot, in: modelContext)
            self.undoSnapshot = nil
            didApply = false
            prepareProposal()
            refreshTransitionNotifications(
                for: activities.filter { affectedIDs.contains($0.id) }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func tomorrowMorning(for date: Date) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func accessibilityDescription(
        for change: ReplanChange,
        conflict: ReplanConflict?
    ) -> String {
        if conflict != nil {
            return change.title + ". Horaire initial " + formattedTime(change.originalStart) + ". Une décision est nécessaire."
        }

        if change.isFixedTime {
            return change.title + ". Horaire fixe à " + formattedTime(change.originalStart) + ". Inchangé."
        }

        if change.action == .shifted {
            return change.title + ". Horaire initial " + formattedTime(change.originalStart) + ". Nouvel horaire proposé " + formattedTime(change.proposedStart) + "."
        }

        return change.title
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
