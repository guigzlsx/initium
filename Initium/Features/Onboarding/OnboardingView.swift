import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: EntryFlowViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    viewModel.goBackInOnboarding()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("entry.back"))

                Spacer()

                Text(viewModel.progressLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .accessibilityLabel(Text("entry.progress.accessibility"))

                Spacer()

                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("INITIUM")
                        .font(AppTheme.Typography.caption)
                        .tracking(1.8)
                        .foregroundStyle(AppTheme.accent)

                    Text(questionTitle)
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("onboarding.question.subtitle")
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)

                    answerOptions
                }
                .padding(.top, 28)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)

            Button {
                viewModel.continueOnboarding()
            } label: {
                Text(viewModel.onboardingStep == viewModel.totalOnboardingSteps - 1 ? "onboarding.finish" : "entry.continue")
            }
            .buttonStyle(InitiumPrimaryButtonStyle())
            .disabled(!viewModel.isCurrentQuestionAnswered)
            .opacity(viewModel.isCurrentQuestionAnswered ? 1 : 0.45)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppTheme.screenHorizontalPadding)
        .initiumScreen()
    }

    private var questionTitle: LocalizedStringKey {
        switch viewModel.onboardingStep {
        case 0: "onboarding.question.difficulty"
        case 1: "onboarding.question.pattern"
        case 2: "onboarding.question.guidance"
        default: "onboarding.question.goal"
        }
    }

    @ViewBuilder
    private var answerOptions: some View {
        VStack(spacing: 12) {
            switch viewModel.onboardingStep {
            case 0:
                ForEach(PrimaryDifficulty.allCases) { value in
                    optionButton(
                        titleKey: value.titleKey,
                        selected: viewModel.onboardingPreferences.primaryDifficulty == value
                    ) {
                        viewModel.select(value)
                    }
                }
            case 1:
                ForEach(CommonPattern.allCases) { value in
                    optionButton(
                        titleKey: value.titleKey,
                        selected: viewModel.onboardingPreferences.commonPattern == value
                    ) {
                        viewModel.select(value)
                    }
                }
            case 2:
                ForEach(GuidanceStyle.allCases) { value in
                    optionButton(
                        titleKey: value.titleKey,
                        selected: viewModel.onboardingPreferences.guidanceStyle == value
                    ) {
                        viewModel.select(value)
                    }
                }
            default:
                ForEach(MainGoal.allCases) { value in
                    optionButton(
                        titleKey: value.titleKey,
                        selected: viewModel.onboardingPreferences.mainGoal == value
                    ) {
                        viewModel.select(value)
                    }
                }
            }
        }
    }

    private func optionButton(
        titleKey: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            InitiumHaptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                Text(LocalizedStringKey(titleKey))
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? AppTheme.accent : AppTheme.mutedText)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(selected ? AppTheme.accent.opacity(0.13) : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius)
                    .stroke(selected ? AppTheme.accent.opacity(0.45) : AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(selected ? "entry.selected" : "entry.not_selected"))
    }
}
