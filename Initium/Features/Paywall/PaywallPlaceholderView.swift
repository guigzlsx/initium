import SwiftUI

struct PaywallPlaceholderView: View {
    let onContinue: () -> Void
    @State private var selectedPlan: Plan = .annual

    enum Plan: String, CaseIterable, Identifiable {
        case annual
        case monthly

        var id: String { rawValue }
    }

    private let benefits = [
        "entry.paywall.benefit.transition",
        "entry.paywall.benefit.reset",
        "entry.paywall.benefit.routines",
        "entry.paywall.benefit.calibration",
        "entry.paywall.benefit.insights"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 34)

                Text("entry.paywall.badge")
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.accent)

                Text("entry.paywall.title")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.top, 12)

                Text("entry.paywall.subtitle")
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(benefits, id: \.self) { benefit in
                        Label(LocalizedStringKey(benefit), systemImage: "checkmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
                .padding(22)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .padding(.top, 28)

                VStack(spacing: 12) {
                    planButton(
                        .annual,
                        titleKey: "entry.paywall.annual",
                        priceKey: "entry.paywall.annual_price",
                        detailKey: "entry.paywall.recommended"
                    )
                    planButton(
                        .monthly,
                        titleKey: "entry.paywall.monthly",
                        priceKey: "entry.paywall.monthly_price",
                        detailKey: "entry.paywall.coming_soon"
                    )
                }
                .padding(.top, 18)

                Button(action: onContinue) {
                    Text("entry.paywall.cta")
                }
                .buttonStyle(InitiumPrimaryButtonStyle())
                .padding(.top, 24)

                Button("entry.paywall.restore") { }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(true)
                    .accessibilityHint(Text("entry.paywall.restore_hint"))

                Text("entry.paywall.placeholder_note")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .initiumScreen()
    }

    private func planButton(_ plan: Plan, titleKey: String, priceKey: String, detailKey: String) -> some View {
        Button {
            InitiumHaptics.selection()
            selectedPlan = plan
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(LocalizedStringKey(titleKey))
                        .font(AppTheme.Typography.caption)
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.mutedText)

                    Spacer()

                    if plan == .annual {
                        Text("entry.paywall.recommended_badge")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                Text(LocalizedStringKey(priceKey))
                    .font(AppTheme.Typography.metricLarge)
                    .foregroundStyle(AppTheme.primaryText)

                Text(LocalizedStringKey(detailKey))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: plan == .annual ? 118 : 92, alignment: .leading)
            .padding(.horizontal, 20)
            .background(selectedPlan == plan ? AppTheme.accent.opacity(0.13) : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                    .stroke(selectedPlan == plan ? AppTheme.accent.opacity(0.45) : AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(selectedPlan == plan ? "entry.selected" : "entry.not_selected"))
    }
}
