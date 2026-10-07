import SwiftUI

struct AccountPlaceholderView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 48)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 62, height: 62)
                    .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)

                Text("entry.account.title")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.top, 28)

                Text("entry.account.subtitle")
                    .font(.title3)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)

                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Label("entry.account.apple", systemImage: "apple.logo")
                    }
                    .buttonStyle(InitiumPrimaryButtonStyle())

                    Button(action: onContinue) {
                        Text("entry.account.email")
                    }
                    .buttonStyle(InitiumSecondaryButtonStyle())
                }
                .padding(.top, 34)

                Text("entry.account.local_note")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.hidden)
        .initiumScreen()
    }
}
