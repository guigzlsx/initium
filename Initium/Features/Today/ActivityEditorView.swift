import SwiftUI
import SwiftData

struct ActivityEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Routine.name)
    private var routines: [Routine]

    let activity: Activity?
    let day: Date

    @State private var title: String
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var customDurationText: String
    @State private var usesCustomDuration: Bool
    @State private var isFixedTime: Bool
    @State private var selectedRoutineID: UUID?
    @State private var transitionMarginMinutes: Int
    @State private var notes: String
    @State private var showingDeleteConfirmation = false
    @State private var showingNotificationPrompt = false
    @State private var notificationActivity: Activity?
    @State private var saveErrorMessage: String?
    @FocusState private var focusedField: Field?

    private let routineCalibration = RoutineCalibration()

    private enum Field: Hashable {
        case title
        case customDuration
    }

    init(activity: Activity?, day: Date) {
        self.activity = activity
        self.day = day

        let initialDuration = max(1, (activity?.estimatedDurationSeconds ?? 30 * 60) / 60)

        _title = State(initialValue: activity?.title ?? "")
        _startTime = State(initialValue: activity?.scheduledStartAt ?? Self.defaultStartTime(for: day))
        _durationMinutes = State(initialValue: initialDuration)
        _customDurationText = State(initialValue: "\(initialDuration)")
        _usesCustomDuration = State(initialValue: ![5, 15, 30, 45, 60].contains(initialDuration))
        _isFixedTime = State(initialValue: activity?.isFixedTime ?? false)
        _selectedRoutineID = State(initialValue: activity?.routine?.id)
        _transitionMarginMinutes = State(initialValue: max(0, (activity?.transitionMarginSeconds ?? 5 * 60) / 60))
        _notes = State(initialValue: activity?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: InitiumSpacing.lg) {
                    VStack(alignment: .leading, spacing: 12) {
                        InitiumSectionHeader(eyebrow: "ACTIVITÉ")
                        TextField("Titre", text: $title)
                            .font(AppTheme.Typography.cardTitle)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .title)
                            .submitLabel(.done)
                            .padding(16)
                            .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
                    }
                    .initiumCard()

                    VStack(alignment: .leading, spacing: 12) {
                        InitiumSectionHeader(eyebrow: "QUAND")
                        DatePicker(
                            "Heure de début",
                            selection: $startTime,
                            displayedComponents: .hourAndMinute
                        )
                        .tint(AppTheme.accent)
                    }
                    .initiumCard()

                    VStack(alignment: .leading, spacing: 12) {
                        InitiumSectionHeader(eyebrow: "DURÉE ESTIMÉE")
                        durationChoices

                        if usesCustomDuration {
                            HStack {
                                TextField("Minutes", text: $customDurationText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                    .focused($focusedField, equals: .customDuration)

                                Text("minutes")
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .padding(16)
                            .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
                        }
                    }
                    .initiumCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Horaire fixe", isOn: $isFixedTime)

                        if isFixedTime {
                            Text("Initium évitera de déplacer cette activité lors d'une future réorganisation.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    .initiumCard()

                    VStack(alignment: .leading, spacing: 12) {
                        InitiumSectionHeader(eyebrow: "ROUTINE")
                        Picker("Routine associée", selection: $selectedRoutineID) {
                            Text("Aucune").tag(nil as UUID?)

                            ForEach(routines) { routine in
                                Text(routine.name).tag(Optional(routine.id))
                            }
                        }
                        .pickerStyle(.menu)

                        if let routine = selectedRoutine {
                            transitionPreview(for: routine)
                        }
                    }
                    .initiumCard()

                    VStack(alignment: .leading, spacing: 12) {
                        InitiumSectionHeader(eyebrow: "NOTES")
                        TextEditor(text: $notes)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 90)
                    }
                    .initiumCard()

                    if activity != nil {
                        Menu {
                            Button("Reporter") {
                                updateStatus(.postponed)
                            }

                            Button("Ignorer") {
                                updateStatus(.skipped)
                            }

                            Button("Supprimer", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                        } label: {
                            Label("Actions secondaires", systemImage: "ellipsis.circle")
                                .frame(maxWidth: .infinity, minHeight: AppTheme.controlHeight)
                        }
                        .buttonStyle(InitiumSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.vertical, InitiumSpacing.md)
            }
            .scrollIndicators(.hidden)
            .initiumScreen()
            .navigationTitle(activity == nil ? "Nouvelle activité" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(activity == nil ? "Ajouter" : "Enregistrer") {
                        save()
                    }
                    .disabled(trimmedTitle.isEmpty || resolvedDurationMinutes <= 0)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Terminer") {
                        focusedField = nil
                    }
                }
            }
            .confirmationDialog(
                "Supprimer cette activité ?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    deleteActivity()
                }

                Button("Annuler", role: .cancel) { }
            }
            .alert("Activer les rappels de préparation ?", isPresented: $showingNotificationPrompt) {
                Button("Activer les rappels") {
                    NotificationPermissionTracker.markOffered()
                    scheduleNotificationForPendingActivity()
                }

                Button("Plus tard", role: .cancel) {
                    NotificationPermissionTracker.markOffered()
                    dismiss()
                }
            } message: {
                Text("Initium peut te prévenir quand il est temps de commencer à te préparer.")
            }
            .alert("Impossible d'enregistrer cette modification.", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Réessaie dans un instant.")
            }
            .onAppear {
                focusedField = .title
            }
        }
    }

    private var durationChoices: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([5, 15, 30, 45, 60], id: \.self) { minutes in
                    Button {
                        durationMinutes = minutes
                        customDurationText = "\(minutes)"
                        usesCustomDuration = false
                    } label: {
                        Text(minutes == 60 ? "1 h" : "\(minutes) min")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                !usesCustomDuration && durationMinutes == minutes
                                    ? AppTheme.accent.opacity(0.16)
                                    : AppTheme.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: InitiumRadius.medium)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: InitiumRadius.medium)
                                    .stroke(!usesCustomDuration && durationMinutes == minutes ? AppTheme.accent.opacity(0.42) : AppTheme.border, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    usesCustomDuration = true
                    focusedField = .customDuration
                } label: {
                    Text("Custom")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                usesCustomDuration
                                    ? AppTheme.accent.opacity(0.18)
                                    : AppTheme.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: InitiumRadius.medium)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: InitiumRadius.medium)
                                    .stroke(usesCustomDuration ? AppTheme.accent.opacity(0.42) : AppTheme.border, lineWidth: 1)
                            }
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel("Durées rapides")
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedDurationMinutes: Int {
        if usesCustomDuration {
            return Int(customDurationText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }

        return durationMinutes
    }

    private var selectedRoutine: Routine? {
        routines.first { $0.id == selectedRoutineID }
    }

    private func transitionPreview(for routine: Routine) -> some View {
        let calibration = routineCalibration.result(for: routine)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Préparation", systemImage: "figure.walk.motion")
                Spacer()
                Text(routine.name)
                    .foregroundStyle(AppTheme.mutedText)
            }

            HStack {
                Text("Préparation estimée")
                Spacer()
                Text(ActivityTiming.durationText(seconds: transitionPlan?.routineDurationSeconds ?? calibration.estimatedDurationSeconds))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
            }

            if calibration.hasEnoughHistory {
                InitiumCalibrationCard(
                    estimatedSeconds: calibration.estimatedDurationSeconds,
                    recommendedSeconds: calibration.recommendedDurationSeconds,
                    observationCount: calibration.observationCount,
                    actionTitle: "Utiliser \(ActivityTiming.durationText(seconds: calibration.recommendedDurationSeconds))",
                    onUseRecommendation: applyCalibration
                )
            } else {
                Text("La durée réelle apparaîtra après 3 préparations terminées.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
            }

            Picker("Marge", selection: $transitionMarginMinutes) {
                Text("Aucune").tag(0)
                Text("5 min").tag(5)
                Text("10 min").tag(10)
                Text("15 min").tag(15)
            }

            if let plan = transitionPlan {
                HStack {
                    Text("Début estimé")
                    Spacer()
                    Text(plan.transitionStart, format: .dateTime.hour().minute())
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(InitiumLocalization.string(
            "editor.preparation_accessibility",
            routine.name,
            ActivityTiming.durationText(seconds: transitionPlan?.routineDurationSeconds ?? calibration.estimatedDurationSeconds),
            transitionMarginMinutes
        ))
    }

    private var transitionPlan: TransitionPlan? {
        guard let routine = selectedRoutine else { return nil }

        return TransitionPlanner().makePlan(
            scheduledStart: startTime,
            estimatedRoutineDurationSeconds: routine.estimatedDurationSeconds,
            transitionMarginSeconds: transitionMarginMinutes * 60,
            samples: routineCalibration.samples(for: routine)
        )
    }

    private func applyCalibration() {
        guard let routine = selectedRoutine else { return }
        let recommendation = routineCalibration.result(for: routine).recommendedDurationSeconds
        let minutes = max(1, Int(ceil(Double(recommendation) / 60)))
        durationMinutes = minutes
        customDurationText = String(minutes)
        usesCustomDuration = true
    }

    private func save() {
        let routine = selectedRoutine
        let durationSeconds = resolvedDurationMinutes * 60
        let savedActivity: Activity

        if let activity {
            activity.title = trimmedTitle
            activity.scheduledStartAt = startTime
            activity.estimatedDurationSeconds = durationSeconds
            activity.isFixedTime = isFixedTime
            activity.notes = notes
            activity.routine = routine
            activity.transitionMarginSeconds = transitionMarginMinutes * 60
            savedActivity = activity
        } else {
            let newActivity = Activity(
                title: trimmedTitle,
                scheduledStartAt: startTime,
                estimatedDurationSeconds: durationSeconds,
                isFixedTime: isFixedTime,
                notes: notes
            )
            newActivity.originalScheduledStartAt = startTime
            newActivity.routine = routine
            newActivity.transitionMarginSeconds = transitionMarginMinutes * 60
            modelContext.insert(newActivity)
            savedActivity = newActivity
        }

        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = error.localizedDescription
            return
        }

        if routine != nil && NotificationPermissionTracker.shouldOffer {
            notificationActivity = savedActivity
            showingNotificationPrompt = true
        } else {
            scheduleNotificationIfAuthorized(for: savedActivity)
            dismiss()
        }
    }

    private func updateStatus(_ status: ActivityStatus) {
        activity?.status = status
        do {
            try modelContext.save()
            if let activity, status == .postponed || status == .skipped || status == .cancelled {
                LocalNotificationScheduler().remove(for: activity)
            }
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func deleteActivity() {
        if let activity {
            LocalNotificationScheduler().remove(for: activity)
            modelContext.delete(activity)
            do {
                try modelContext.save()
            } catch {
                saveErrorMessage = error.localizedDescription
            }
        }

        if saveErrorMessage == nil {
            dismiss()
        }
    }

    private func scheduleNotificationForPendingActivity() {
        guard let activity = notificationActivity else {
            dismiss()
            return
        }

        Task { @MainActor in
            let scheduler = LocalNotificationScheduler()
            if (try? await scheduler.requestAuthorization()) == true {
                if let plan = TransitionPlanner().makePlan(for: activity) {
                    do {
                        try await scheduler.schedule(for: activity, plan: plan)
                    } catch {
                        saveErrorMessage = error.localizedDescription
                    }
                }
            }
            dismiss()
        }
    }

    private func scheduleNotificationIfAuthorized(for activity: Activity) {
        Task { @MainActor in
            let scheduler = LocalNotificationScheduler()
            guard await scheduler.isAuthorized() else {
                scheduler.remove(for: activity)
                return
            }

            if let plan = TransitionPlanner().makePlan(for: activity) {
                do {
                    try await scheduler.schedule(for: activity, plan: plan)
                } catch {
                    saveErrorMessage = error.localizedDescription
                }
            } else {
                scheduler.remove(for: activity)
            }
        }
    }

    private static func defaultStartTime(for day: Date) -> Date {
        let calendar = Calendar.current
        let now = Date.now

        if calendar.isDate(day, inSameDayAs: now) {
            return now
        }

        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }
}

#Preview("Activity editor") {
    ActivityEditorView(activity: nil, day: .now)
        .modelContainer(PersistenceController.preview)
}
