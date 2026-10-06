import SwiftUI

struct InitiumCalibrationCard: View {
    let estimatedSeconds: Int
    let recommendedSeconds: Int
    let observationCount: Int
    let actionTitle: String?
    let onUseRecommendation: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(AppTheme.warmAccent)

                Text("CALIBRATION LOCALE")
                    .font(AppTheme.Typography.caption)
                    .tracking(1.7)
                    .foregroundStyle(AppTheme.mutedText)
            }

                Text(InitiumLocalization.string("calibration.planned", durationText(estimatedSeconds)))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            HStack(alignment: .firstTextBaseline) {
                Text("Habituellement")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text(durationText(recommendedSeconds))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
            }

            Text(InitiumLocalization.string("calibration.based_on_sessions_period", observationCount))
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)

            if let actionTitle, let onUseRecommendation {
                Button(actionTitle, action: onUseRecommendation)
                    .buttonStyle(InitiumSecondaryButtonStyle())
            }
        }
        .padding(20)
        .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: InitiumRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: InitiumRadius.large)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(InitiumLocalization.string(
            "calibration.accessibility",
            durationText(estimatedSeconds),
            durationText(recommendedSeconds),
            observationCount
        ))
    }

    private func durationText(_ seconds: Int) -> String {
        ActivityTiming.durationText(seconds: seconds)
    }
}

struct InitiumProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.surfaceElevated)
                Capsule()
                    .fill(AppTheme.accent)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
