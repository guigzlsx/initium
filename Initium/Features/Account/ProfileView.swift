import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var preferredLocale = "fr"
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    let authentication: AuthenticationService

    init(authentication: AuthenticationService) {
        self.authentication = authentication
        displayName = authentication.profile?.displayName ?? ""
        preferredLocale = authentication.profile?.preferredLocale ?? Locale.current.language.languageCode?.identifier ?? "fr"
    }

    var email: String { authentication.currentUser?.email ?? "" }

    func load() async {
        guard authentication.profile == nil else { return }
        _ = try? await authentication.fetchProfile()
        displayName = authentication.profile?.displayName ?? ""
        preferredLocale = authentication.profile?.preferredLocale ?? preferredLocale
    }

    func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = InitiumLocalization.string("auth.error.display_name")
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await authentication.updateProfile(
                displayName: trimmedName,
                preferredLocale: preferredLocale
            )
        } catch let error as AuthenticationError {
            errorMessage = InitiumLocalization.string(error.localizationKey)
        } catch {
            errorMessage = InitiumLocalization.string("auth.error.generic")
        }
    }
}

@MainActor
final class ChangePasswordViewModel: ObservableObject {
    @Published var password = ""
    @Published var confirmation = ""
    @Published var isPasswordVisible = false
    @Published var isConfirmationVisible = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSave = false

    let authentication: AuthenticationService

    init(authentication: AuthenticationService) {
        self.authentication = authentication
    }

    func save() async {
        guard password.count >= 6 else {
            errorMessage = InitiumLocalization.string("auth.error.weak_password")
            return
        }
        guard password == confirmation else {
            errorMessage = InitiumLocalization.string("auth.error.password_mismatch")
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authentication.updatePassword(password)
            didSave = true
        } catch let error as AuthenticationError {
            errorMessage = InitiumLocalization.string(error.localizationKey)
        } catch {
            errorMessage = InitiumLocalization.string("auth.error.generic")
        }
    }
}

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authentication: AuthenticationService
    @StateObject private var viewModel: ProfileViewModel
    @State private var showingChangePassword = false
    @State private var showingDeleteConfirmation = false
    @State private var showingFinalDeleteConfirmation = false

    init(authentication: AuthenticationService) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(authentication: authentication))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InitiumSpacing.md) {
                Text("auth.profile.eyebrow")
                    .font(AppTheme.Typography.caption)
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.accent)

                Text("auth.profile.title")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundStyle(AppTheme.primaryText)

                VStack(alignment: .leading, spacing: InitiumSpacing.md) {
                    profileField("auth.email", value: viewModel.email)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("auth.display_name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                        TextField("auth.display_name", text: $viewModel.displayName)
                            .textContentType(.name)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
                            .overlay {
                                RoundedRectangle(cornerRadius: InitiumRadius.medium)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            }
                    }

                    Picker("auth.preferred_locale", selection: $viewModel.preferredLocale) {
                        Text("auth.locale.fr").tag("fr")
                        Text("auth.locale.en").tag("en")
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primaryText)
                }
                .initiumCard(padding: 20)

                Button {
                    Task { await viewModel.save() }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isLoading { ProgressView().tint(.white) }
                        Text("auth.profile.save")
                    }
                }
                .buttonStyle(InitiumPrimaryButtonStyle())
                .disabled(viewModel.isLoading)

                Button("auth.change_password") {
                    showingChangePassword = true
                }
                .buttonStyle(InitiumSecondaryButtonStyle())

                Button("auth.sign_out") {
                    Task { await authentication.signOut() }
                }
                .buttonStyle(InitiumSecondaryButtonStyle())

                Button("auth.delete_account", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.red)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, InitiumSpacing.md)
            .padding(.bottom, InitiumSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .initiumScreen()
        .navigationTitle(LocalizedStringKey("auth.profile.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView(authentication: authentication)
        }
        .confirmationDialog(
            "auth.delete_account.confirm_title",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("auth.delete_account.continue", role: .destructive) {
                showingFinalDeleteConfirmation = true
            }
            Button("auth.cancel", role: .cancel) { }
        } message: {
            Text("auth.delete_account.confirm_message")
        }
        .confirmationDialog(
            "auth.delete_account.final_title",
            isPresented: $showingFinalDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("auth.delete_account.confirm", role: .destructive) {
                Task { try? await authentication.deleteAccount() }
            }
            Button("auth.cancel", role: .cancel) { }
        } message: {
            Text("auth.delete_account.final_message")
        }
        .task { await viewModel.load() }
    }

    private func profileField(_ label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.body)
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .padding(.horizontal, 16)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: InitiumRadius.medium))
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChangePasswordViewModel

    init(authentication: AuthenticationService) {
        _viewModel = StateObject(wrappedValue: ChangePasswordViewModel(authentication: authentication))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("auth.change_password.title")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.primaryText)

                    passwordField("auth.password", text: $viewModel.password, visible: $viewModel.isPasswordVisible)
                    passwordField("auth.password_confirmation", text: $viewModel.confirmation, visible: $viewModel.isConfirmationVisible)

                    Button {
                        Task { await viewModel.save() }
                    } label: {
                        HStack(spacing: 10) {
                            if viewModel.isLoading { ProgressView().tint(.white) }
                            Text("auth.change_password.save")
                        }
                    }
                    .buttonStyle(InitiumPrimaryButtonStyle())
                    .disabled(viewModel.isLoading)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, InitiumSpacing.xl)
            }
            .scrollIndicators(.hidden)
            .initiumScreen()
            .navigationTitle(LocalizedStringKey("auth.change_password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("auth.cancel") { dismiss() }
                }
            }
            .onChange(of: viewModel.didSave) { _, didSave in
                if didSave { dismiss() }
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
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button { visible.wrappedValue.toggle() } label: {
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
}

struct PasswordRecoveryView: View {
    @EnvironmentObject private var authentication: AuthenticationService

    var body: some View {
        ChangePasswordView(authentication: authentication)
    }
}
