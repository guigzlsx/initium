import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 54)

                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)

                Spacer(minLength: 34)

                VStack(alignment: .leading, spacing: 16) {
                    Text("entry.welcome.eyebrow")
                        .font(AppTheme.Typography.caption)
                        .tracking(1.8)
                        .foregroundStyle(AppTheme.accent)

                    Text("entry.welcome.title")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.primaryText)

                    Text("entry.welcome.subtitle")
                        .font(.title3)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(26)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: InitiumRadius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: InitiumRadius.card)
                        .stroke(AppTheme.border, lineWidth: 1)
                }

                Spacer(minLength: 42)

                Button(action: onContinue) {
                    Text("entry.welcome.cta")
                }
                .buttonStyle(InitiumPrimaryButtonStyle())
                .accessibilityHint(Text("entry.welcome.cta_hint"))
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.hidden)
        .initiumScreen()
    }
}
