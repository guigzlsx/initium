import SwiftUI

struct RoutineDetailView: View {
    let routine: Routine
    private let calibration = RoutineCalibration()

    var body: some View {
        let result = calibration.result(for: routine)

        ScrollView {
            VStack(alignment: .leading, spacing: InitiumSpacing.lg) {
                hero(result: result)

                VStack(alignment: .leading, spacing: InitiumSpacing.md) {
                    InitiumSectionHeader(eyebrow: "ÉTAPES")

                    ForEach(routine.orderedSteps) { step in
                        HStack(spacing: 14) {
                            Text("\(step.order + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.accent.opacity(0.14), in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(ActivityTiming.durationText(seconds: step.estimatedDurationSeconds))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .initiumCard()

                if result.recentDurationsSeconds.count >= 3 {
                    historyCard(result: result)
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

    private func hero(result: RoutineCalibrationResult) -> some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.lg) {
            HStack {
                Image(systemName: routine.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.accent.opacity(0.14), in: Circle())

                Spacer()

                Text(InitiumLocalization.string("routine.steps", routine.orderedSteps.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }

            Text(routine.name)
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.primaryText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metrics(result: result)
                }
                VStack(spacing: 12) {
                    metrics(result: result)
                }
            }

            if !result.hasEnoughHistory {
                Text("La durée habituelle apparaîtra après 3 préparations terminées.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .initiumCard()
    }

    @ViewBuilder
    private func metrics(result: RoutineCalibrationResult) -> some View {
        InitiumMetricCard(
            label: "estimation initiale",
            value: ActivityTiming.durationText(seconds: result.estimatedDurationSeconds)
        )

        InitiumMetricCard(
            label: "temps réel moyen",
            value: result.hasEnoughHistory
                ? ActivityTiming.durationText(seconds: result.recommendedDurationSeconds)
                : "—",
            detail: result.hasEnoughHistory
                ? InitiumLocalization.string("routine.sessions", result.observationCount)
                : nil
        )
    }

    private func historyCard(result: RoutineCalibrationResult) -> some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.md) {
            InitiumSectionHeader(eyebrow: "HISTORIQUE")

            ForEach(Array(result.recentDurationsSeconds.enumerated()), id: \.offset) { _, duration in
                HStack {
                    Text(ActivityTiming.durationText(seconds: duration))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText)

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
