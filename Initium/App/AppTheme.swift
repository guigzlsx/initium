import SwiftUI

enum InitiumRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 18
    static let large: CGFloat = 24
    static let card: CGFloat = 30
}

enum InitiumSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 26
    static let xl: CGFloat = 36
    static let screen: CGFloat = 20
}

enum InitiumTheme {
    // The dark palette is the product reference. Light mode keeps the same
    // hierarchy with a warm, quiet surface instead of a stark inversion.
    static let background = adaptive(
        light: UIColor(red: 0.955, green: 0.948, blue: 0.932, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.035, blue: 0.051, alpha: 1)
    )
    static let surface = adaptive(
        light: UIColor(red: 1, green: 0.998, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.106, green: 0.106, blue: 0.125, alpha: 1)
    )
    static let surfaceElevated = adaptive(
        light: UIColor(red: 0.925, green: 0.921, blue: 0.907, alpha: 1),
        dark: UIColor(red: 0.133, green: 0.133, blue: 0.153, alpha: 1)
    )
    static let border = adaptive(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.white.withAlphaComponent(0.085)
    )
    static let primaryText = adaptive(
        light: UIColor(red: 0.075, green: 0.073, blue: 0.08, alpha: 1),
        dark: UIColor(red: 0.969, green: 0.969, blue: 0.976, alpha: 1)
    )
    static let secondaryText = adaptive(
        light: UIColor(red: 0.36, green: 0.355, blue: 0.37, alpha: 1),
        dark: UIColor(red: 0.643, green: 0.643, blue: 0.682, alpha: 1)
    )
    static let mutedText = adaptive(
        light: UIColor(red: 0.51, green: 0.50, blue: 0.52, alpha: 1),
        dark: UIColor(red: 0.435, green: 0.435, blue: 0.475, alpha: 1)
    )
    static let accent = adaptive(
        light: UIColor(red: 0.22, green: 0.34, blue: 0.68, alpha: 1),
        dark: UIColor(red: 0.58, green: 0.67, blue: 0.98, alpha: 1)
    )
    static let warmAccent = adaptive(
        light: UIColor(red: 0.66, green: 0.38, blue: 0.19, alpha: 1),
        dark: UIColor(red: 0.87, green: 0.62, blue: 0.40, alpha: 1)
    )

    enum Spacing {
        static let compact = InitiumSpacing.sm
        static let standard = InitiumSpacing.md
        static let section = InitiumSpacing.lg
        static let screen = InitiumSpacing.screen
    }

    enum Typography {
        static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.heavy)
        static let metricXL = Font.system(.largeTitle, design: .rounded).weight(.heavy)
        static let metricLarge = Font.system(.title, design: .rounded).weight(.bold)
        static let cardTitle = Font.system(.title3, design: .rounded).weight(.bold)
        static let body = Font.body
        static let secondary = Font.subheadline
        static let caption = Font.caption.weight(.bold)
    }

    // Compatibility aliases keep the existing domain views readable while
    // moving all visual decisions to the new token vocabulary.
    static let calmBackground = background
    static let cardBackground = surface
    static let elevatedBackground = surfaceElevated
    static let screenHorizontalPadding = InitiumSpacing.screen
    static let cardCornerRadius = InitiumRadius.card
    static let controlCornerRadius = InitiumRadius.medium
    static let controlHeight: CGFloat = 56

    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

typealias AppTheme = InitiumTheme

struct InitiumCardModifier: ViewModifier {
    var padding: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: InitiumRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: InitiumRadius.card)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    func initiumCard(padding: CGFloat = 24) -> some View {
        modifier(InitiumCardModifier(padding: padding))
    }

    func initiumScreen() -> some View {
        background(AppTheme.background.ignoresSafeArea())
    }

    func initiumLargeMetric() -> some View {
        modifier(InitiumLargeMetricModifier())
    }
}

private struct InitiumLargeMetricModifier: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .heavy, design: .rounded))
    }
}

struct InitiumSectionHeader: View {
    let eyebrow: String
    var title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.xs) {
            Text(LocalizedStringKey(eyebrow))
                .font(AppTheme.Typography.caption)
                .tracking(1.7)
                .foregroundStyle(AppTheme.mutedText)

            if let title {
                Text(title)
                    .font(AppTheme.Typography.cardTitle)
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
        VStack(alignment: .leading, spacing: InitiumSpacing.xs) {
            Text(value)
                .font(AppTheme.Typography.metricLarge)
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)

            Text(LocalizedStringKey(label))
                .font(AppTheme.Typography.caption)
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

struct InitiumMetricCard: View {
    let label: String
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.sm) {
            Text(LocalizedStringKey(label))
                .font(AppTheme.Typography.caption)
                .tracking(1.2)
                .foregroundStyle(AppTheme.mutedText)

            Text(value)
                .font(AppTheme.Typography.metricLarge)
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .initiumCard(padding: 20)
    }
}

struct InitiumRemainingMetric: View {
    let seconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ActivityTiming.durationText(seconds: seconds))
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .foregroundStyle(AppTheme.primaryText)

            Text(LocalizedStringKey("duration.remaining_label"))
                .font(AppTheme.Typography.secondary.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(InitiumLocalization.string("duration.accessibility.remaining", ActivityTiming.durationText(seconds: seconds)))
    }
}

struct InitiumIconButton: View {
    let systemName: String
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 52, height: 52)
                .background(AppTheme.surfaceElevated, in: Circle())
                .overlay {
                    Circle().stroke(AppTheme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct InitiumPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: AppTheme.controlHeight)
            .padding(.horizontal, 20)
            .background(AppTheme.accent.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
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
            .frame(maxWidth: .infinity, minHeight: AppTheme.controlHeight)
            .padding(.horizontal, 18)
            .background(AppTheme.surfaceElevated.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: InitiumRadius.medium)
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
            .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                isSelected ? AppTheme.accent.opacity(0.16) : AppTheme.surfaceElevated,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(isSelected ? AppTheme.accent.opacity(0.42) : AppTheme.border, lineWidth: 1)
            }
    }
}
