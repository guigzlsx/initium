import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor
final class CalendarIntegrationViewModel: ObservableObject {
    @Published private(set) var authorizationStatus: CalendarAuthorizationStatus
    @Published private(set) var calendars: [CalendarDescriptor] = []
    @Published private(set) var selectedCalendarIdentifiers: Set<String>
    @Published private(set) var syncState: CalendarSyncState = .idle
    @Published var errorMessage: String?

    let provider: any CalendarEventProvider
    private let preferences: CalendarPreferencesStore

    init(
        provider: (any CalendarEventProvider)? = nil,
        defaults: UserDefaults = .standard
    ) {
        let resolvedProvider = provider ?? EventKitCalendarProvider()
        self.provider = resolvedProvider
        self.preferences = CalendarPreferencesStore(defaults: defaults)
        self.authorizationStatus = resolvedProvider.authorizationStatus()
        self.selectedCalendarIdentifiers = self.preferences.selectedCalendarIdentifiers
    }

    var isConnected: Bool {
        preferences.isEnabled && authorizationStatus == .fullAccess
    }

    var selectedCount: Int {
        selectedCalendarIdentifiers.count
    }

    func load() async {
        authorizationStatus = provider.authorizationStatus()
        guard authorizationStatus == .fullAccess else {
            calendars = []
            return
        }

        do {
            calendars = try await provider.fetchCalendars()
            if selectedCalendarIdentifiers.isEmpty, !calendars.isEmpty, !preferences.isEnabled {
                selectedCalendarIdentifiers = Set(calendars.map(\.id))
                preferences.setSelectedCalendarIdentifiers(selectedCalendarIdentifiers)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await provider.requestAccess()
            authorizationStatus = provider.authorizationStatus()
            guard granted, authorizationStatus == .fullAccess else { return false }

            preferences.setEnabled(true)
            await load()
            if selectedCalendarIdentifiers.isEmpty {
                selectedCalendarIdentifiers = Set(calendars.map(\.id))
                preferences.setSelectedCalendarIdentifiers(selectedCalendarIdentifiers)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func toggleCalendar(_ calendar: CalendarDescriptor, in context: ModelContext) async {
        var updated = selectedCalendarIdentifiers
        if updated.contains(calendar.id) {
            updated.remove(calendar.id)
        } else {
            updated.insert(calendar.id)
        }

        let disabled = selectedCalendarIdentifiers.subtracting(updated)
        selectedCalendarIdentifiers = updated
        preferences.setSelectedCalendarIdentifiers(updated)

        do {
            let service = CalendarSyncService(provider: provider, preferences: preferences)
            if !disabled.isEmpty {
                _ = try service.removeExternalActivities(for: disabled, in: context)
            }
            try await sync(using: service, in: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectAll(in context: ModelContext) async {
        selectedCalendarIdentifiers = Set(calendars.map(\.id))
        preferences.setSelectedCalendarIdentifiers(selectedCalendarIdentifiers)
        await refreshAndSync(in: context)
    }

    func deselectAll(in context: ModelContext) async {
        let previous = selectedCalendarIdentifiers
        selectedCalendarIdentifiers = []
        preferences.setSelectedCalendarIdentifiers([])

        do {
            let service = CalendarSyncService(provider: provider, preferences: preferences)
            _ = try service.removeExternalActivities(for: previous, in: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAndSync(in context: ModelContext) async {
        await load()
        guard isConnected else { return }

        do {
            let service = CalendarSyncService(provider: provider, preferences: preferences)
            try await sync(using: service, in: context)
        } catch {
            errorMessage = error.localizedDescription
            syncState = .failed
        }
    }

    func disconnect(in context: ModelContext) {
        do {
            let service = CalendarSyncService(provider: provider, preferences: preferences)
            _ = try service.removeExternalActivities(
                for: selectedCalendarIdentifiers,
                in: context
            )
            preferences.reset()
            selectedCalendarIdentifiers = []
            syncState = .idle
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func sync(
        using service: CalendarSyncService,
        in context: ModelContext
    ) async throws {
        syncState = .syncing
        _ = try await service.sync(in: context)
        syncState = .succeeded
    }
}
