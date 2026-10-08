import SwiftUI
import UIKit

@MainActor
final class AuthenticationViewModel: ObservableObject {
    enum Mode {
        case landing
        case signUp
        case signIn
        case resetPassword
    }

    @Published var mode: Mode = .landing
    @Published var displayName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var passwordConfirmation = ""
    @Published var isPasswordVisible = false
    @Published var isConfirmationVisible = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var resetSent = false

    let authentication: AuthenticationService

    init(authentication: AuthenticationService) {
        self.authentication = authentication
    }

    func show(_ mode: Mode) {
        self.mode = mode
        errorMessage = nil
        resetSent = false
    }

    func submitSignUp() async {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = InitiumLocalization.string("auth.error.display_name")
            return
        }
        guard isValidEmail(address) else {
            errorMessage = InitiumLocalization.string("auth.error.invalid_email")
            return
        }
        guard password.count >= 6 else {
            errorMessage = InitiumLocalization.string("auth.error.weak_password")
            return
        }
        guard password == passwordConfirmation else {
            errorMessage = InitiumLocalization.string("auth.error.password_mismatch")
            return
        }

        await perform {
            try await self.authentication.signUp(email: address, password: self.password, displayName: name)
        }
    }

    func submitSignIn() async {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(address), !password.isEmpty else {
            errorMessage = InitiumLocalization.string("auth.error.invalid_credentials")
            return
        }

        await perform {
            try await self.authentication.signIn(email: address, password: self.password)
        }
    }

    func submitReset() async {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(address) else {
            errorMessage = InitiumLocalization.string("auth.error.invalid_email")
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authentication.sendPasswordReset(email: address)
            resetSent = true
        } catch let error as AuthenticationError {
            errorMessage = InitiumLocalization.string(error.localizationKey)
        } catch {
            errorMessage = InitiumLocalization.string("auth.error.generic")
        }
    }

    private func perform(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch let error as AuthenticationError {
            errorMessage = InitiumLocalization.string(error.localizationKey)
        } catch {
            errorMessage = InitiumLocalization.string("auth.error.generic")
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        value.contains("@") && value.contains(".")
    }
}

struct AccountView: View {
    @StateObject private var viewModel: AuthenticationViewModel

    init(authentication: AuthenticationService) {
        _viewModel = StateObject(wrappedValue: AuthenticationViewModel(authentication: authentication))
    }

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

                Group {
                    switch viewModel.mode {
                    case .landing:
                        landing
                    case .signUp:
                        signUp
                    case .signIn:
                        signIn
                    case .resetPassword:
                        resetPassword
                    }
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.hidden)
        .initiumScreen()
    }

    private var landing: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("auth.landing.eyebrow")
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.accent)

            Text("auth.landing.title")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.top, 12)

            Text("auth.landing.subtitle")
                .font(.title3)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            VStack(spacing: 12) {
                Button("auth.create_account") {
                    viewModel.show(.signUp)
                }
                .buttonStyle(InitiumPrimaryButtonStyle())

                Button("auth.already_have_account") {
                    viewModel.show(.signIn)
                }
                .buttonStyle(InitiumSecondaryButtonStyle())
            }
            .padding(.top, 34)

            Text("auth.local_data_note")
                .font(.caption)
                .foregroundStyle(AppTheme.mutedText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 30)
        }
    }

    private var signUp: some View {
        authForm(
            eyebrow: "auth.signup.eyebrow",
            title: "auth.signup.title",
            subtitle: "auth.signup.subtitle",
            submitTitle: "auth.signup.submit",
            submit: { await viewModel.submitSignUp() }
        ) {
            labeledField("auth.display_name", text: $viewModel.displayName, contentType: .name)
            labeledField("auth.email", text: $viewModel.email, contentType: .emailAddress)
            passwordField("auth.password", text: $viewModel.password, visible: $viewModel.isPasswordVisible)
            passwordField("auth.password_confirmation", text: $viewModel.passwordConfirmation, visible: $viewModel.isConfirmationVisible)
        }
    }

    private var signIn: some View {
        authForm(
            eyebrow: "auth.signin.eyebrow",
            title: "auth.signin.title",
            subtitle: "auth.signin.subtitle",
            submitTitle: "auth.signin.submit",
            submit: { await viewModel.submitSignIn() }
        ) {
            labeledField("auth.email", text: $viewModel.email, contentType: .emailAddress)
            passwordField("auth.password", text: $viewModel.password, visible: $viewModel.isPasswordVisible)

            Button("auth.forgot_password") {
                viewModel.show(.resetPassword)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }

    private var resetPassword: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.show(.signIn)
            } label: {
                Label("auth.back_to_signin", systemImage: "chevron.left")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .frame(minHeight: 44, alignment: .leading)

            Text("auth.reset.eyebrow")
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 22)

            Text("auth.reset.title")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.top, 12)

            Text("auth.reset.subtitle")
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.top, 14)

            if viewModel.resetSent {
                Text("auth.reset.sent")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .initiumCard(padding: 18)
                    .padding(.top, 26)
            } else {
                labeledField("auth.email", text: $viewModel.email, contentType: .emailAddress)
                    .padding(.top, 24)

                submitButton("auth.reset.submit") {
                    await viewModel.submitReset()
                }
                .padding(.top, 18)
            }

            errorText
        }
    }

    private func authForm<Fields: View>(
        eyebrow: LocalizedStringKey,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        submitTitle: LocalizedStringKey,
        submit: @escaping () async -> Void,
        @ViewBuilder fields: () -> Fields
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                viewModel.show(.landing)
            } label: {
                Label("auth.back", systemImage: "chevron.left")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .frame(minHeight: 44, alignment: .leading)

            Text(eyebrow)
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 22)

            Text(title)
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.top, 12)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.top, 14)

            VStack(spacing: 14) {
                fields()
            }
            .padding(.top, 26)

            submitButton(submitTitle, action: submit)
                .padding(.top, 20)

            errorText
        }
    }

    private func labeledField(
        _ label: LocalizedStringKey,
        text: Binding<String>,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            TextField(label, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(contentType == .name ? .words : .never)
                .autocorrectionDisabled(contentType != .name)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: InitiumRadius.medium)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
        }
    }

    private func passwordField(
        _ label: LocalizedStringKey,
        text: Binding<String>,
        visible: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 10) {
                Group {
                    if visible.wrappedValue {
                        TextField(label, text: text)
                    } else {
                        SecureField(label, text: text)
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    visible.wrappedValue.toggle()
                } label: {
                    Image(systemName: visible.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(visible.wrappedValue ? "auth.hide_password" : "auth.show_password")
            }
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .frame(minHeight: 56)
            .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: InitiumRadius.medium)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
    }

    private func submitButton(_ title: LocalizedStringKey, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                }
                Text(title)
            }
        }
        .buttonStyle(InitiumPrimaryButtonStyle())
        .disabled(viewModel.isLoading)
        .accessibilityValue(viewModel.isLoading ? Text("auth.loading") : Text("") )
    }

    @ViewBuilder
    private var errorText: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}
