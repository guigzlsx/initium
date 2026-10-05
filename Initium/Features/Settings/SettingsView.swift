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
    @AppStorage("initium.appearance") private var appearance = InitiumAppearance.system.rawValue

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("APPARENCE") {
                    Picker("Apparence", selection: $appearance) {
                        Text("Système").tag(InitiumAppearance.system.rawValue)
                        Text("Clair").tag(InitiumAppearance.light.rawValue)
                        Text("Sombre").tag(InitiumAppearance.dark.rawValue)
                    }
                }

                Section("RAPPELS") {
                    HStack {
                        Label("Notifications", systemImage: "bell")
                        Spacer()
                        Text(notificationStatusText)
                            .foregroundStyle(.secondary)
                    }

                    if notificationStatus == .denied {
                        Text("Les rappels sont désactivés. Tu peux les réactiver dans les réglages de l’iPhone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Ouvrir les réglages") {
                            openSystemSettings()
                        }
                    }
                }

                Section("DONNÉES ET CONFIDENTIALITÉ") {
                    Text("Tes données restent sur cet appareil. Initium n’utilise aucun compte et n’envoie pas tes activités à un serveur.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Effacer toutes mes données", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }

                Section("À PROPOS") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                }
            }
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                }
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
}
