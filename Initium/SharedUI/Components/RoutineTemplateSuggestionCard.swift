import SwiftUI

struct RoutineTemplateSuggestionCard: View {
    let match: RoutineTemplateMatch
    let catalog: RoutineTemplateCatalog
    let isApplying: Bool
    let onUse: () -> Void

    private var locale: RoutineTemplateLocale { .current }
    private var templateSteps: [RoutineTemplateStep] { catalog.steps(for: match.template) }
    private var durationSeconds: Int {
        templateSteps.reduce(0) { $0 + $1.estimatedDurationSeconds }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: match.template.icon ?? "checklist")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("routine_template.suggestion_eyebrow"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)

                    Text(match.template.localizedName(for: locale))
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundStyle(AppTheme.primaryText)

                    Text(InitiumLocalization.string(
                        "routine_template.summary",
                        templateSteps.count,
                        ActivityTiming.durationText(seconds: durationSeconds)
                    ))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 0)
            }

            if let description = match.template.localizedDescription(for: locale), !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(templateSteps.prefix(4)) { step in
                    Label(step.localizedTitle(for: locale), systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Button {
                onUse()
            } label: {
                HStack {
                    if isApplying {
                        ProgressView()
                            .tint(AppTheme.primaryText)
                    }
                    Text(LocalizedStringKey("routine_template.use"))
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .disabled(isApplying)
        }
        .initiumCard(padding: 16)
        .accessibilityElement(children: .contain)
    }
}
