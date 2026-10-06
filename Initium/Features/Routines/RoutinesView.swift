import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Query(sort: \Routine.name)
    private var routines: [Routine]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: InitiumSpacing.lg) {
                    pageHeader

                    if routines.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 156), spacing: InitiumSpacing.sm)],
                            spacing: InitiumSpacing.sm
                        ) {
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
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, InitiumSpacing.md)
                .padding(.bottom, InitiumSpacing.xl)
            }
            .scrollIndicators(.hidden)
            .initiumScreen()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ROUTINES")
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.accent)

            Text("Routines")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text("Des préparations simples, prêtes quand tu en as besoin.")
                .font(AppTheme.Typography.secondary)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.md) {
            Image(systemName: "checklist")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppTheme.accent)

            Text("Aucune routine")
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text("Les routines réutilisables apparaîtront ici.")
                .font(AppTheme.Typography.secondary)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .initiumCard()
    }
}

private struct RoutineCard: View {
    let routine: Routine
    private let calibration = RoutineCalibration()

    var body: some View {
        let result = calibration.result(for: routine)

        VStack(alignment: .leading, spacing: InitiumSpacing.md) {
            HStack {
                Image(systemName: routine.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.accent.opacity(0.14), in: Circle())

                Spacer()

                Text(InitiumLocalization.string("routine.steps", routine.orderedSteps.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }

            Text(routine.name)
                .font(AppTheme.Typography.cardTitle)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(ActivityTiming.durationText(seconds: result.recommendedDurationSeconds))
                    .font(AppTheme.Typography.metricLarge)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)

                Text(LocalizedStringKey(result.hasEnoughHistory ? "temps réel moyen" : "estimation initiale"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if result.hasEnoughHistory {
                Text(InitiumLocalization.string("routine.sessions", result.observationCount))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .initiumCard(padding: 18)
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
