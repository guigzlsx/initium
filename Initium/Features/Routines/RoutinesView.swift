import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Query(sort: \Routine.name)
    private var routines: [Routine]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Routines")
                            .font(.largeTitle.weight(.bold))
                        Text("Des préparations simples, prêtes quand tu en as besoin.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if routines.isEmpty {
                        ContentUnavailableView(
                            "Aucune routine",
                            systemImage: "checklist",
                            description: Text("Les routines réutilisables apparaîtront ici.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(routines) { routine in
                            NavigationLink {
                                RoutineDetailView(routine: routine)
                            } label: {
                                RoutineCard(routine: routine)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.vertical, AppTheme.Spacing.standard)
            }
            .scrollIndicators(.hidden)
            .initiumScreen()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct RoutineCard: View {
    let routine: Routine
    private let calibration = RoutineCalibration()

    var body: some View {
        let result = calibration.result(for: routine)

        HStack(spacing: 16) {
            Image(systemName: routine.icon)
                .font(.title2.weight(.medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 48, height: 48)
                .background(AppTheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 7) {
                Text(routine.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(InitiumLocalization.string("routine.steps", routine.orderedSteps.count))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)

                if result.hasEnoughHistory {
                    Text(InitiumLocalization.string("routine.average_duration", ActivityTiming.durationText(seconds: result.recommendedDurationSeconds)))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.warmAccent)
                } else {
                    Text(InitiumLocalization.string("routine.estimated_duration", ActivityTiming.durationText(seconds: result.estimatedDurationSeconds)))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mutedText)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.mutedText)
        }
        .initiumCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(routineAccessibilityLabel(result))
    }

    private func routineAccessibilityLabel(_ result: RoutineCalibrationResult) -> String {
        let duration = result.hasEnoughHistory
            ? InitiumLocalization.string("routine.accessibility.average", ActivityTiming.durationText(seconds: result.recommendedDurationSeconds), result.observationCount)
            : InitiumLocalization.string("routine.accessibility.estimate", ActivityTiming.durationText(seconds: result.estimatedDurationSeconds))
        return InitiumLocalization.string("routine.accessibility", routine.name, routine.orderedSteps.count, duration)
    }
}

#Preview("Routines") {
    RoutinesView()
        .modelContainer(PersistenceController.preview)
}
