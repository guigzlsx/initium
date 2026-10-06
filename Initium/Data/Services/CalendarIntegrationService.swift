import EventKit
import Foundation

enum CalendarAuthorizationStatus: Equatable {
    case notDetermined
    case fullAccess
    case writeOnly
    case denied
    case restricted
}

struct CalendarDescriptor: Identifiable, Equatable {
    let id: String
    let title: String
    let colorHex: String?
    let sourceTitle: String?
}

struct CalendarEventDescriptor: Identifiable, Equatable {
    let id: String
    let calendarIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let lastModifiedAt: Date?
}

enum CalendarProviderError: LocalizedError, Equatable {
    case accessDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return InitiumLocalization.string("calendar.error.access_denied")
        case .unavailable:
            return InitiumLocalization.string("calendar.error.unavailable")
        }
    }
}

@MainActor
protocol CalendarEventProvider: AnyObject {
    func authorizationStatus() -> CalendarAuthorizationStatus
    func requestAccess() async throws -> Bool
    func fetchCalendars() async throws -> [CalendarDescriptor]
    func fetchEvents(
        calendarIdentifiers: Set<String>,
        startDate: Date,
        endDate: Date
    ) async throws -> [CalendarEventDescriptor]
}

@MainActor
final class EventKitCalendarProvider: CalendarEventProvider {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func authorizationStatus() -> CalendarAuthorizationStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess, .authorized:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async throws -> Bool {
        guard #available(iOS 17.0, *) else {
            throw CalendarProviderError.unavailable
        }

        return try await eventStore.requestFullAccessToEvents()
    }

    func fetchCalendars() async throws -> [CalendarDescriptor] {
        guard authorizationStatus() == .fullAccess else {
            throw CalendarProviderError.accessDenied
        }

        return eventStore.calendars(for: .event).map { calendar in
            CalendarDescriptor(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                colorHex: calendar.cgColor.flatMap(Self.hexColor),
                sourceTitle: calendar.source?.title
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func fetchEvents(
        calendarIdentifiers: Set<String>,
        startDate: Date,
        endDate: Date
    ) async throws -> [CalendarEventDescriptor] {
        guard authorizationStatus() == .fullAccess else {
            throw CalendarProviderError.accessDenied
        }

        let calendars = eventStore.calendars(for: .event).filter {
            calendarIdentifiers.contains($0.calendarIdentifier)
        }
        guard !calendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        return eventStore.events(matching: predicate).compactMap { event in
            let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
            guard let start = event.startDate,
                  let end = event.endDate else {
                return nil
            }

            return CalendarEventDescriptor(
                id: identifier,
                calendarIdentifier: event.calendar.calendarIdentifier,
                title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? event.title!.trimmingCharacters(in: .whitespacesAndNewlines)
                    : InitiumLocalization.string("calendar.untitled_event"),
                startDate: start,
                endDate: max(start, end),
                isAllDay: event.isAllDay,
                location: event.location,
                notes: event.notes,
                lastModifiedAt: event.lastModifiedDate
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }

    private static func hexColor(_ color: CGColor) -> String? {
        guard let components = color.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?.components,
              components.count >= 3 else {
            return nil
        }

        let red = Int((components[0] * 255).rounded())
        let green = Int((components[1] * 255).rounded())
        let blue = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

struct CalendarPreferencesStore {
    private let defaults: UserDefaults

    private enum Key {
        static let enabled = "initium.calendar.enabled"
        static let selectedCalendarIdentifiers = "initium.calendar.selectedCalendarIdentifiers"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        defaults.bool(forKey: Key.enabled)
    }

    var selectedCalendarIdentifiers: Set<String> {
        Set(defaults.stringArray(forKey: Key.selectedCalendarIdentifiers) ?? [])
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.enabled)
    }

    func setSelectedCalendarIdentifiers(_ identifiers: Set<String>) {
        defaults.set(Array(identifiers).sorted(), forKey: Key.selectedCalendarIdentifiers)
    }

    func reset() {
        defaults.removeObject(forKey: Key.enabled)
        defaults.removeObject(forKey: Key.selectedCalendarIdentifiers)
    }
}

#if DEBUG
@MainActor
final class MockCalendarEventProvider: CalendarEventProvider {
    var status: CalendarAuthorizationStatus
    var calendars: [CalendarDescriptor]
    var events: [CalendarEventDescriptor]
    var requestAccessResult: Bool
    var fetchError: Error?

    init(
        status: CalendarAuthorizationStatus = .fullAccess,
        calendars: [CalendarDescriptor] = [],
        events: [CalendarEventDescriptor] = [],
        requestAccessResult: Bool = true
    ) {
        self.status = status
        self.calendars = calendars
        self.events = events
        self.requestAccessResult = requestAccessResult
    }

    func authorizationStatus() -> CalendarAuthorizationStatus { status }

    func requestAccess() async throws -> Bool {
        status = requestAccessResult ? .fullAccess : .denied
        return requestAccessResult
    }

    func fetchCalendars() async throws -> [CalendarDescriptor] {
        if let fetchError { throw fetchError }
        return calendars
    }

    func fetchEvents(
        calendarIdentifiers: Set<String>,
        startDate: Date,
        endDate: Date
    ) async throws -> [CalendarEventDescriptor] {
        if let fetchError { throw fetchError }
        return events.filter {
            calendarIdentifiers.contains($0.calendarIdentifier) &&
            $0.startDate < endDate &&
            $0.endDate >= startDate
        }
    }
}
#endif
