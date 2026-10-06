import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \Activity.scheduledStartAt)
    private var activities: [Activity]

    @Query(sort: \Routine.name)
    private var routines: [Routine]

    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: InitiumSpacing.lg) {
                    header
                    periodPicker

                    if let snapshot = viewModel.snapshot {
                        snapshotContent(snapshot)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
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
            .task(id: refreshKey) {
                viewModel.refresh(activities: activities, routines: routines)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INSIGHTS")
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.accent)

            Text("Insights")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text("Des repères simples, basés sur ce que tu as réellement fait.")
                .font(AppTheme.Typography.secondary)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 10) {
            ForEach(InsightsPeriod.allCases) { period in
                Button {
                    viewModel.period = period
                } label: {
                    Text(LocalizedStringKey(period.title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.period == period ? AppTheme.primaryText : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            viewModel.period == period ? AppTheme.surfaceElevated : AppTheme.surface,
                            in: RoundedRectangle(cornerRadius: InitiumRadius.medium)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: InitiumRadius.medium)
                                .stroke(viewModel.period == period ? AppTheme.accent.opacity(0.42) : AppTheme.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Période des insights")
    }

    @ViewBuilder
    private func snapshotContent(_ snapshot: InsightsSnapshot) -> some View {
        if !snapshot.hasObservations {
            learningState
        } else {
            overallCalibrationCard(snapshot.overallCalibration)

            if !snapshot.routineInsights.isEmpty {
                routineCard(snapshot.routineInsights)
            }

            if let startDelay = snapshot.startDelay {
                startDelayCard(startDelay)
            }

            if !snapshot.underestimatedActivities.isEmpty ||
                !snapshot.wellCalibratedActivities.isEmpty ||
                snapshot.replan.replannedActivityCount > 0 {
                patternsCard(snapshot)
            }
        }
    }

    private var learningState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(AppTheme.warmAccent)

            Text("Initium apprend ton rythme.")
                .font(.title3.weight(.semibold))

            Text("Les tendances apparaîtront à mesure que tu utilises l’app.")
                .foregroundStyle(AppTheme.secondaryText)
        }
        .initiumCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func overallCalibrationCard(_ insight: CalibrationInsight?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("TON TEMPS")

            if let insight, insight.isReliable {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        InitiumMetricCard(label: "Prévu", value: durationText(insight.estimatedAverageSeconds))
                        InitiumMetricCard(label: "Réel", value: durationText(insight.actualAverageSeconds))
                    }
                    VStack(spacing: 12) {
                        InitiumMetricCard(label: "Prévu", value: durationText(insight.estimatedAverageSeconds))
                        InitiumMetricCard(label: "Réel", value: durationText(insight.actualAverageSeconds))
                    }
                }

                comparisonBars(
                    estimated: insight.estimatedAverageSeconds,
                    actual: insight.actualAverageSeconds
                )

                Text(InitiumLocalization.string("insights.completed_activities", insight.observationCount))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                learningMessage(observationCount: insight?.observationCount ?? 0)
            }
        }
        .initiumCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(overallAccessibilityLabel(insight))
    }

    private func routineCard(_ insights: [RoutineInsight]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("PRÉPARATION")

            ForEach(Array(insights.prefix(3))) { insight in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(insight.name)
                            .font(AppTheme.Typography.cardTitle)
                        Spacer()
                        if insight.isReliable {
                            Text(InitiumLocalization.string("insights.times", insight.observationCount))
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }

                    if insight.isReliable {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                InitiumMetricCard(label: "Prévu", value: durationText(insight.estimatedDurationSeconds))
                                InitiumMetricCard(label: "Réel moyen", value: durationText(insight.actualAverageSeconds))
                            }
                            VStack(spacing: 12) {
                                InitiumMetricCard(label: "Prévu", value: durationText(insight.estimatedDurationSeconds))
                                InitiumMetricCard(label: "Réel moyen", value: durationText(insight.actualAverageSeconds))
                            }
                        }
                        comparisonBars(
                            estimated: insight.estimatedDurationSeconds,
                            actual: insight.actualAverageSeconds
                        )
                    } else {
                        learningMessage(observationCount: insight.observationCount)
                    }

                    if insight.recentDurationsSeconds.count >= 3 {
                        Text(InitiumLocalization.string(
                            "insights.recent",
                            insight.recentDurationsSeconds.map(durationText).joined(separator: " · ")
                        ))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                if insight.id != insights.prefix(3).last?.id {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                }
            }
        }
        .initiumCard()
        .accessibilityElement(children: .contain)
    }

    private func startDelayCard(_ insight: StartDelayInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DÉMARRAGE")

            if insight.isReliable {
                Text(startDelayText(seconds: insight.averageDelaySeconds))
                    .font(AppTheme.Typography.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)

                Text(InitiumLocalization.string("insights.starts", insight.observationCount))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                learningMessage(observationCount: insight.observationCount)
            }
        }
        .initiumCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(startDelayAccessibilityLabel(insight))
    }

    private func patternsCard(_ snapshot: InsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !snapshot.underestimatedActivities.isEmpty {
                sectionLabel("PLUS LONG QUE PRÉVU")

                ForEach(snapshot.underestimatedActivities) { insight in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(AppTheme.Typography.cardTitle)
                            Text(InitiumLocalization.string("insights.longer_average", durationText(insight.differenceSeconds)))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Text(InitiumLocalization.string("insights.times", insight.observationCount))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }

            if !snapshot.wellCalibratedActivities.isEmpty {
                if !snapshot.underestimatedActivities.isEmpty {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                }

                sectionLabel("BIEN CALIBRÉ")
                ForEach(snapshot.wellCalibratedActivities) { insight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(AppTheme.Typography.cardTitle)
                        Text(InitiumLocalization.string("insights.calibrated", durationText(insight.estimatedAverageSeconds), durationText(insight.actualAverageSeconds)))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }

            if snapshot.replan.replannedActivityCount > 0 {
                if !snapshot.underestimatedActivities.isEmpty || !snapshot.wellCalibratedActivities.isEmpty {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                }

                sectionLabel("RÉORGANISATIONS")
                Text(replanText(snapshot.replan))
                    .font(.subheadline.weight(.medium))
            }
        }
        .initiumCard()
        .accessibilityElement(children: .contain)
    }

    private func comparisonBars(estimated: Int, actual: Int) -> some View {
        GeometryReader { proxy in
            let maximum = max(estimated, actual, 1)

            VStack(alignment: .leading, spacing: 6) {
                bar(
                    label: "Prévu",
                    value: estimated,
                    maximum: maximum,
                    width: proxy.size.width,
                    color: AppTheme.secondaryText
                )
                bar(
                    label: "Réel",
                    value: actual,
                    maximum: maximum,
                    width: proxy.size.width,
                    color: AppTheme.warmAccent
                )
            }
        }
        .frame(height: 42)
        .accessibilityHidden(true)
    }

    private func bar(
        label: String,
        value: Int,
        maximum: Int,
        width: CGFloat,
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 42, alignment: .leading)
                .foregroundStyle(AppTheme.secondaryText)

            Capsule()
                .fill(color.opacity(0.72))
                .frame(width: max(8, (width - 50) * CGFloat(value) / CGFloat(maximum)), height: 8)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppTheme.Typography.metricLarge)
                .monospacedDigit()
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.Typography.caption)
            .tracking(1.7)
            .foregroundStyle(AppTheme.mutedText)
    }

    private func learningMessage(observationCount: Int) -> some View {
        Text(
            observationCount == 0
                ? "Initium apprend encore ton rythme."
                : "Encore un peu tôt pour tirer une tendance."
        )
        .font(.subheadline)
        .foregroundStyle(AppTheme.secondaryText)
    }

    private func durationText(_ seconds: Int) -> String {
        ActivityTiming.durationText(seconds: seconds)
    }

    private func startDelayText(seconds: Int) -> String {
        let minutes = max(1, Int(abs(seconds) / 60))
        if seconds > 60 {
            return InitiumLocalization.string("insights.starts_after", minutes)
        }
        if seconds < -60 {
            return InitiumLocalization.string("insights.starts_before", minutes)
        }
        return InitiumLocalization.string("insights.starts_around")
    }

    private func replanText(_ insight: ReplanInsight) -> String {
        return InitiumLocalization.string(
            "insights.replans",
            insight.replannedDayCount,
            insight.replannedActivityCount
        )
    }

    private func overallAccessibilityLabel(_ insight: CalibrationInsight?) -> String {
        guard let insight, insight.isReliable else {
            return InitiumLocalization.string("insights.overall_learning_accessibility")
        }
        return InitiumLocalization.string(
            "insights.overall_accessibility",
            durationText(insight.estimatedAverageSeconds),
            durationText(insight.actualAverageSeconds),
            insight.observationCount
        )
    }

    private func startDelayAccessibilityLabel(_ insight: StartDelayInsight) -> String {
        InitiumLocalization.string(
            "insights.start_accessibility",
            startDelayText(seconds: insight.averageDelaySeconds),
            insight.observationCount
        )
    }

    private var refreshKey: String {
        let activityKey = activities.map {
            [
                $0.id.uuidString,
                $0.title,
                $0.statusRawValue,
                String($0.estimatedDurationSeconds),
                String($0.actualDurationSeconds),
                String($0.scheduledStartAt.timeIntervalSince1970),
                String($0.originalScheduledStartAt?.timeIntervalSince1970 ?? 0),
                String($0.sessions.count),
                $0.completedAt?.description ?? ""
            ].joined(separator: "-")
        }.joined(separator: "|")
        let routineKey = routines.map {
            let sessionKey = $0.sessions.map {
                [
                    $0.id.uuidString,
                    $0.statusRawValue,
                    String($0.actualDurationSeconds),
                    String($0.startedAt.timeIntervalSince1970),
                    String($0.endedAt?.timeIntervalSince1970 ?? 0)
                ].joined(separator: ":")
            }.joined(separator: ",")
            return [$0.id.uuidString, String($0.estimatedDurationSeconds), sessionKey].joined(separator: "-")
        }.joined(separator: "|")
        return viewModel.period.rawValue + activityKey + routineKey
    }
}

#Preview("Insights") {
    InsightsView()
        .modelContainer(PersistenceController.preview)
}
