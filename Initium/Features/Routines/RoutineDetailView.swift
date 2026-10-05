import SwiftUI

struct RoutineDetailView: View {
    let routine: Routine
    private let calibration = RoutineCalibration()

    var body: some View {
        let result = calibration.result(for: routine)

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: routine.icon)
                            .font(.title2)
                            .foregroundStyle(AppTheme.accent)

                        Spacer()

                        Text(InitiumLocalization.string("routine.steps", routine.orderedSteps.count))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Text(routine.name)
                        .font(.largeTitle.weight(.bold))

                    if result.hasEnoughHistory {
                        HStack(spacing: 28) {
                            InitiumMetric(
                                label: "temps réel moyen",
                                value: ActivityTiming.durationText(seconds: result.recommendedDurationSeconds),
                                detail: InitiumLocalization.string("routine.sessions", result.observationCount)
                            )
                            InitiumMetric(
                                label: "estimation initiale",
                                value: ActivityTiming.durationText(seconds: result.estimatedDurationSeconds)
                            )
                        }
                    } else {
                        Text(InitiumLocalization.string("routine.estimated_duration_full", ActivityTiming.durationText(seconds: result.estimatedDurationSeconds)))
                            .font(.title2.weight(.bold))
                        Text("La durée habituelle apparaîtra après 3 préparations terminées.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .initiumCard()

                VStack(alignment: .leading, spacing: 12) {
                    InitiumSectionHeader(eyebrow: "ÉTAPES")

                    ForEach(routine.orderedSteps) { step in
                        HStack(spacing: 14) {
                            Text("\(step.order + 1)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.accent.opacity(0.12), in: Circle())

                            Text(step.title)
                                .font(.body.weight(.semibold))

                            Spacer()

                            Text(ActivityTiming.durationText(seconds: step.estimatedDurationSeconds))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .frame(minHeight: 44)
                    }
                }
                .initiumCard()

                if result.recentDurationsSeconds.count >= 3 {
                    VStack(alignment: .leading, spacing: 14) {
                        InitiumSectionHeader(eyebrow: "HISTORIQUE")

                        ForEach(Array(result.recentDurationsSeconds.enumerated()), id: \.offset) { _, duration in
                            HStack {
                                Text(ActivityTiming.durationText(seconds: duration))
                                    .font(.title3.weight(.bold))
                                    .monospacedDigit()
                                Spacer()
                                Text(InitiumLocalization.string("routine.preparation_label"))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                        }
                    }
                    .initiumCard()
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
