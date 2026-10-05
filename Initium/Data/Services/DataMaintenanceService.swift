import Foundation
import SwiftData

@MainActor
struct DataMaintenanceService {
    func deleteAllData(in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<Activity>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ActivitySession>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<RoutineSession>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<RoutineStep>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<Routine>()).forEach(context.delete)
        try context.save()

        LocalNotificationScheduler.removeAll()
    }
}
