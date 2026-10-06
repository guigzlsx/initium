import SwiftUI
import SwiftData
import UserNotifications
import UIKit

enum InitiumAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entryFlow: EntryFlowViewModel
    @AppStorage("initium.appearance") private var appearance = InitiumAppearance.system.rawValue
    @AppStorage("initium.calendar.enabled") private var calendarEnabled = false

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingDeleteConfirmation = false
    @State private var showingCalendarSettings = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: InitiumSpacing.md) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SETTINGS")
                            .font(AppTheme.Typography.caption)
                            .tracking(1.8)
                            .foregroundStyle(AppTheme.accent)
                        Text("Réglages")
                            .font(AppTheme.Typography.largeTitle)
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    settingsCard(eyebrow: "APPARENCE") {
                        Picker("Apparence", selection: $appearance) {
                            Text("Système").tag(InitiumAppearance.system.rawValue)
                            Text("Clair").tag(InitiumAppearance.light.rawValue)
                            Text("Sombre").tag(InitiumAppearance.dark.rawValue)
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.primaryText)
                    }

                    settingsCard(eyebrow: "RAPPELS") {
                        HStack(spacing: 12) {
                            Image(systemName: "bell")
                                .foregroundStyle(AppTheme.accent)
                            Text("Notifications")
                                .font(.body.weight(.semibold))
                            Spacer()
                            Text(notificationStatusText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        if notificationStatus == .denied {
                            Text("Les rappels sont désactivés. Tu peux les réactiver dans les réglages de l’iPhone.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.secondaryText)

                            Button("Ouvrir les réglages") {
                                openSystemSettings()
                            }
                            .buttonStyle(InitiumSecondaryButtonStyle())
                        }
                    }

                    settingsCard(eyebrow: "CALENDRIER") {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .foregroundStyle(AppTheme.accent)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(LocalizedStringKey("calendar.settings.title"))
                                    .font(.body.weight(.semibold))

                                Text(LocalizedStringKey(calendarEnabled ? "calendar.connected" : "calendar.not_connected"))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedText)
                        }

                        Button(LocalizedStringKey(calendarEnabled ? "calendar.manage" : "calendar.connect.button")) {
                            showingCalendarSettings = true
                        }
                        .buttonStyle(InitiumSecondaryButtonStyle())
                    }

                    settingsCard(eyebrow: "DONNÉES ET CONFIDENTIALITÉ") {
                        Text("Tes données restent sur cet appareil. Initium n’utilise aucun compte et n’envoie pas tes activités à un serveur.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)

                        Button("Effacer toutes mes données", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }

                    settingsCard(eyebrow: "À PROPOS") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(appVersion)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        HStack {
                            Text("Build")
                            Spacer()
                            Text(appBuild)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }

                    #if DEBUG
                    settingsCard(eyebrow: "DEBUG") {
                        Button("Réinitialiser l'entrée") {
                            entryFlow.resetForDevelopment()
                            dismiss()
                        }
                        .buttonStyle(InitiumSecondaryButtonStyle())
                    }
                    #endif
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, InitiumSpacing.md)
                .padding(.bottom, InitiumSpacing.xl)
            }
            .scrollIndicators(.hidden)
            .initiumScreen()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCalendarSettings) {
                CalendarSettingsView()
            }
            .confirmationDialog(
                "Effacer toutes tes données ?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Effacer définitivement", role: .destructive) {
                    deleteAllData()
                }
                Button("Annuler", role: .cancel) { }
            } message: {
                Text("Cette action supprimera les activités, routines et sessions enregistrées sur cet appareil.")
            }
            .alert("Impossible d’effacer les données", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Réessaie dans un instant.")
            }
            .task {
                await refreshNotificationStatus()
            }
        }
    }

    private func settingsCard<Content: View>(
        eyebrow: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.md) {
            Text(LocalizedStringKey(eyebrow))
                .font(AppTheme.Typography.caption)
                .tracking(1.7)
                .foregroundStyle(AppTheme.mutedText)

            content()
        }
        .initiumCard(padding: 20)
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            "Activés"
        case .denied:
            "Désactivés"
        case .notDetermined:
            "Non configurés"
        @unknown default:
            "Non configurés"
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func deleteAllData() {
        do {
            try DataMaintenanceService().deleteAllData(in: modelContext)
            dismiss()
        } catch {
            errorMessage = InitiumLocalization.string("Impossible d'effacer les données")
        }
    }
}

#Preview("Settings") {
    SettingsView()
        .modelContainer(PersistenceController.preview)
        .environmentObject(EntryFlowViewModel())
}
