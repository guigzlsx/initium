import Foundation
import SwiftData
import XCTest
@testable import Initium

@MainActor
final class CalendarSyncServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName = ""
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "CalendarSyncServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        container = nil
        super.tearDown()
    }

    func testDeniedPermissionDoesNotImportOrBlockTheApp() async throws {
        let provider = MockCalendarEventProvider(status: .denied)
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let container = try PersistenceController.makeContainer(inMemory: true)

        let result = try await CalendarSyncService(
            provider: provider,
            preferences: preferences,
            notificationScheduler: nil
        ).sync(in: container.mainContext, now: referenceDate)

        XCTAssertEqual(result, .empty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Activity>()).isEmpty)
    }

    func testWriteOnlyAndRestrictedPermissionDoNotImport() async throws {
        for status in [CalendarAuthorizationStatus.writeOnly, .restricted] {
            let provider = MockCalendarEventProvider(status: status)
            let preferences = makePreferences(enabled: true, selected: ["personal"])
            let context = try makeContext()

            let result = try await service(provider, preferences).sync(in: context, now: referenceDate)

            XCTAssertEqual(result, .empty)
            XCTAssertTrue(try context.fetch(FetchDescriptor<Activity>()).isEmpty)
        }
    }

    func testFirstSyncImportsOneCalendarActivity() async throws {
        let event = makeEvent(identifier: "event-1", title: "Restaurant", calendar: "personal")
        let provider = MockCalendarEventProvider(
            calendars: [makeCalendar(id: "personal", title: "Personnel")],
            events: [event]
        )
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()

        let result = try await service(provider, preferences).sync(in: context, now: referenceDate)
        let activities = try context.fetch(FetchDescriptor<Activity>())

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?.sourceType, .calendar)
        XCTAssertTrue(activities.first?.isFixedTime == true)
        XCTAssertEqual(activities.first?.externalEventIdentifier, "event-1")
    }

    func testSecondSyncDoesNotCreateDuplicate() async throws {
        let event = makeEvent(identifier: "event-1", title: "Restaurant", calendar: "personal")
        let provider = MockCalendarEventProvider(events: [event])
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()
        let sync = service(provider, preferences)

        _ = try await sync.sync(in: context, now: referenceDate)
        let result = try await sync.sync(in: context, now: referenceDate)

        XCTAssertEqual(result.importedCount, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Activity>()).count, 1)
    }

    func testOnlySelectedCalendarsAreImported() async throws {
        let provider = MockCalendarEventProvider(
            events: [
                makeEvent(identifier: "personal-event", title: "Personnel", calendar: "personal"),
                makeEvent(identifier: "work-event", title: "Travail", calendar: "work")
            ]
        )
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()

        _ = try await service(provider, preferences).sync(in: context, now: referenceDate)
        let activities = try context.fetch(FetchDescriptor<Activity>())

        XCTAssertEqual(activities.map(\.externalEventIdentifier), ["personal-event"])
    }

    func testExternalMoveUpdatesTimeAndPreservesRoutineAndMargin() async throws {
        let initial = makeEvent(identifier: "event-1", title: "Restaurant", calendar: "personal")
        let provider = MockCalendarEventProvider(events: [initial])
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()
        let sync = service(provider, preferences)

        _ = try await sync.sync(in: context, now: referenceDate)
        let activity = try XCTUnwrap(try context.fetch(FetchDescriptor<Activity>()).first)
        let routine = Routine(name: "Se préparer")
        routine.steps = [RoutineStep(title: "Douche", estimatedDurationSeconds: 600, order: 0)]
        activity.routine = routine
        activity.transitionMarginSeconds = 600
        context.insert(routine)
        try context.save()

        provider.events = [
            makeEvent(
                identifier: "event-1",
                title: "Restaurant",
                calendar: "personal",
                start: referenceDate.addingTimeInterval(1_800)
            )
        ]
        _ = try await sync.sync(in: context, now: referenceDate)

        XCTAssertEqual(activity.scheduledStartAt, referenceDate.addingTimeInterval(1_800))
        XCTAssertEqual(activity.transitionMarginSeconds, 600)
        XCTAssertEqual(activity.routine?.id, routine.id)
        XCTAssertEqual(activity.sourceType, .calendar)
    }

    func testFutureExternalDeletionRemovesActivity() async throws {
        let event = makeEvent(identifier: "event-1", title: "Restaurant", calendar: "personal")
        let provider = MockCalendarEventProvider(events: [event])
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()
        let sync = service(provider, preferences)

        _ = try await sync.sync(in: context, now: referenceDate)
        provider.events = []
        let result = try await sync.sync(in: context, now: referenceDate)

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Activity>()).isEmpty)
    }

    func testDeselectingCalendarRemovesFutureActivitiesOnlyLocally() async throws {
        let event = makeEvent(identifier: "event-1", title: "Restaurant", calendar: "personal")
        let provider = MockCalendarEventProvider(events: [event])
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()
        let sync = service(provider, preferences)

        _ = try await sync.sync(in: context, now: referenceDate)
        let removed = try sync.removeExternalActivities(for: ["personal"], in: context)

        XCTAssertEqual(removed, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Activity>()).isEmpty)
        XCTAssertEqual(provider.events.count, 1)
    }

    func testSyncFailureKeepsExistingActivities() async throws {
        let event = makeEvent(identifier: "event-1", title: "Restaurant", calendar: "personal")
        let provider = MockCalendarEventProvider(events: [event])
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()
        let sync = service(provider, preferences)

        _ = try await sync.sync(in: context, now: referenceDate)
        provider.fetchError = CalendarProviderError.unavailable

        var didThrow = false
        do {
            _ = try await sync.sync(in: context, now: referenceDate)
        } catch {
            didThrow = true
        }

        XCTAssertTrue(didThrow)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Activity>()).count, 1)
    }

    func testHistoricalExternalDeletionKeepsExecutionHistory() async throws {
        let event = makeEvent(identifier: "event-1", title: "Restaurant", calendar: "personal")
        let provider = MockCalendarEventProvider(events: [event])
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()
        let sync = service(provider, preferences)

        _ = try await sync.sync(in: context, now: referenceDate)
        let activity = try XCTUnwrap(try context.fetch(FetchDescriptor<Activity>()).first)
        activity.status = .completed
        activity.completedAt = referenceDate
        let session = ActivitySession(
            startedAt: referenceDate.addingTimeInterval(-600),
            endedAt: referenceDate,
            actualDurationSeconds: 600
        )
        session.activity = activity
        context.insert(session)
        try context.save()

        provider.events = []
        _ = try await sync.sync(in: context, now: referenceDate)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Activity>()).count, 1)
        XCTAssertTrue(activity.isExternallyDeleted)
        XCTAssertEqual(activity.sessions.count, 1)
    }

    func testAllDayEventIsImportedButNeverBecomesNowOrNext() async throws {
        let event = makeEvent(identifier: "all-day", title: "Anniversaire", calendar: "personal", allDay: true)
        let provider = MockCalendarEventProvider(events: [event])
        let preferences = makePreferences(enabled: true, selected: ["personal"])
        let context = try makeContext()

        _ = try await service(provider, preferences).sync(in: context, now: referenceDate)
        let activity = try XCTUnwrap(try context.fetch(FetchDescriptor<Activity>()).first)

        XCTAssertTrue(activity.externalIsAllDay)
        XCTAssertEqual(activity.estimatedDurationSeconds, 0)
        XCTAssertNil(DayStateResolver().currentActivity(from: [activity], now: referenceDate))
        XCTAssertNil(DayStateResolver().nextActivity(from: [activity], now: referenceDate))
        XCTAssertNil(TransitionPlanner().makePlan(for: activity))
    }

    func testMigrationDefaultsExistingActivityToLocalSource() throws {
        let context = try makeContext()
        let activity = Activity(
            title: "Travail",
            scheduledStartAt: referenceDate,
            estimatedDurationSeconds: 1_800
        )
        context.insert(activity)
        try context.save()

        XCTAssertEqual(activity.sourceType, .local)
        XCTAssertNil(activity.externalEventIdentifier)
        XCTAssertNil(activity.externalCalendarIdentifier)
        XCTAssertFalse(activity.externalIsAllDay)
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }

    private func makeContext() throws -> ModelContext {
        container = try PersistenceController.makeContainer(inMemory: true)
        return container.mainContext
    }

    private func makePreferences(enabled: Bool, selected: Set<String>) -> CalendarPreferencesStore {
        let preferences = CalendarPreferencesStore(defaults: defaults)
        preferences.setEnabled(enabled)
        preferences.setSelectedCalendarIdentifiers(selected)
        return preferences
    }

    private func service(
        _ provider: MockCalendarEventProvider,
        _ preferences: CalendarPreferencesStore
    ) -> CalendarSyncService {
        CalendarSyncService(
            provider: provider,
            preferences: preferences,
            notificationScheduler: nil
        )
    }

    private func makeCalendar(id: String, title: String) -> CalendarDescriptor {
        CalendarDescriptor(id: id, title: title, colorHex: nil, sourceTitle: "iCloud")
    }

    private func makeEvent(
        identifier: String,
        title: String,
        calendar: String,
        start: Date? = nil,
        allDay: Bool = false
    ) -> CalendarEventDescriptor {
        let startDate = start ?? referenceDate.addingTimeInterval(3_600)
        return CalendarEventDescriptor(
            id: identifier,
            calendarIdentifier: calendar,
            title: title,
            startDate: startDate,
            endDate: allDay ? startDate.addingTimeInterval(86_400) : startDate.addingTimeInterval(3_600),
            isAllDay: allDay,
            location: nil,
            notes: nil,
            lastModifiedAt: referenceDate
        )
    }
}
