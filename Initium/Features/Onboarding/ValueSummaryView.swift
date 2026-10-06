import SwiftUI

struct ValueSummaryView: View {
    @ObservedObject var viewModel: EntryFlowViewModel
    let onContinue: () -> Void

    private let benefits = [
        "entry.summary.benefit.start",
        "entry.summary.benefit.transition",
        "entry.summary.benefit.reset",
        "entry.summary.benefit.rhythm"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 46)

                Text("entry.summary.eyebrow")
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.accent)

                Text("entry.summary.title")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.top, 12)

                Text(LocalizedStringKey(personalizedMessageKey))
                    .font(.title3)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)

                VStack(spacing: 12) {
                    ForEach(Array(benefits.enumerated()), id: \.element) { index, benefit in
                        HStack(alignment: .top, spacing: 14) {
                            Text("0\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.accent.opacity(0.14), in: Circle())

                            Text(LocalizedStringKey(benefit))
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundStyle(AppTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: InitiumRadius.card))
                        .overlay {
                            RoundedRectangle(cornerRadius: InitiumRadius.card)
                                .stroke(AppTheme.border, lineWidth: 1)
                        }
                    }
                }
                .padding(.top, 34)

                Button(action: onContinue) {
                    Text("entry.summary.cta")
                }
                .buttonStyle(InitiumPrimaryButtonStyle())
                .padding(.top, 34)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .initiumScreen()
    }

    private var personalizedMessageKey: String {
        switch viewModel.onboardingPreferences.primaryDifficulty {
        case .startingTask:
            "entry.summary.personalized.start"
        case .changingActivities:
            "entry.summary.personalized.transition"
        case .estimatingTime:
            "entry.summary.personalized.time"
        default:
            "entry.summary.personalized.default"
        }
    }
}
