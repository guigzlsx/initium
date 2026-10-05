import Foundation
import SwiftData

@MainActor
enum PersistenceController {
    static let schema = InitiumSchemaV1.schema

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: InitiumMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static var preview: ModelContainer = {
        do {
            let container = try makeContainer(inMemory: true)
            PreviewData.insert(into: container.mainContext)
            return container
        } catch {
            fatalError("Unable to create the Initium preview container: \(error)")
        }
    }()
}

enum InitiumSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Activity.self,
            ActivitySession.self,
            Routine.self,
            RoutineStep.self,
            RoutineSession.self
        ]
    }

    static let schema = Schema(models)
}

enum InitiumMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [InitiumSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
