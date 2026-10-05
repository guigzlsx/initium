import SwiftUI

enum AppTheme {
    // Initium uses one quiet accent and lets hierarchy, space and contrast do
    // most of the visual work.
    static let accent = adaptive(
        light: UIColor(red: 0.25, green: 0.39, blue: 0.68, alpha: 1),
        dark: UIColor(red: 0.49, green: 0.62, blue: 0.98, alpha: 1)
    )
    static let warmAccent = adaptive(
        light: UIColor(red: 0.78, green: 0.45, blue: 0.22, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.64, blue: 0.39, alpha: 1)
    )

    static let calmBackground = adaptive(
        light: UIColor(red: 0.955, green: 0.952, blue: 0.965, alpha: 1),
        dark: UIColor(red: 0.025, green: 0.025, blue: 0.035, alpha: 1)
    )
    static let cardBackground = adaptive(
        light: UIColor.white,
        dark: UIColor(red: 0.105, green: 0.105, blue: 0.125, alpha: 1)
    )
    static let elevatedBackground = adaptive(
        light: UIColor(red: 0.985, green: 0.983, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.145, green: 0.145, blue: 0.17, alpha: 1)
    )
    static let border = adaptive(
        light: UIColor.black.withAlphaComponent(0.07),
        dark: UIColor.white.withAlphaComponent(0.09)
    )
    static let primaryText = adaptive(
        light: UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    )
    static let secondaryText = adaptive(
        light: UIColor(red: 0.38, green: 0.38, blue: 0.43, alpha: 1),
        dark: UIColor(red: 0.64, green: 0.64, blue: 0.69, alpha: 1)
    )
    static let mutedText = adaptive(
        light: UIColor(red: 0.53, green: 0.53, blue: 0.58, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1)
    )

    enum Spacing {
        static let compact: CGFloat = 8
        static let standard: CGFloat = 16
        static let section: CGFloat = 24
        static let screen: CGFloat = 20
    }

    static let cardCornerRadius: CGFloat = 28
    static let controlCornerRadius: CGFloat = 16
    static let controlHeight: CGFloat = 52
    static let screenHorizontalPadding: CGFloat = 20

    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct InitiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 18, y: 8)
    }
}

extension View {
    func initiumCard() -> some View {
        modifier(InitiumCardModifier())
    }

    func initiumScreen() -> some View {
        background(AppTheme.calmBackground.ignoresSafeArea())
    }
}

struct InitiumSectionHeader: View {
    let eyebrow: String
    var title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(eyebrow))
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.mutedText)

            if let title {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct InitiumMetric: View {
    let label: String
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)

            Text(LocalizedStringKey(label))
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct InitiumPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: AppTheme.controlHeight)
            .padding(.horizontal, 18)
            .background(AppTheme.accent.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct InitiumSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(AppTheme.primaryText)
            .frame(minHeight: AppTheme.controlHeight)
            .padding(.horizontal, 16)
            .background(AppTheme.elevatedBackground.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct InitiumPill: View {
    let title: String
    var isSelected = false

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected ? AppTheme.accent.opacity(0.14) : AppTheme.elevatedBackground,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(isSelected ? AppTheme.accent.opacity(0.24) : AppTheme.border, lineWidth: 1)
            }
    }
}
