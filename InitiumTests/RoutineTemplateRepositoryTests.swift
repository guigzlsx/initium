import XCTest
@testable import Initium

final class RoutineTemplateRepositoryTests: XCTestCase {
    func testCacheRoundTrip() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = RoutineTemplateCacheStore(fileURL: fileURL)
        let catalog = makeCatalog(slug: "cached")

        try await store.save(catalog)
        let loaded = try await store.load()
        XCTAssertEqual(loaded, catalog)
    }

    func testRepositoryFallsBackToBundledCatalogAndCachesRemoteRefresh() async throws {
        let fileURL = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = RoutineTemplateCacheStore(fileURL: fileURL)
        let bundled = makeCatalog(slug: "bundled")
        let remote = StubRemote(catalog: makeCatalog(slug: "remote"))
        let repository = RoutineTemplateRepository(
            cache: store,
            remote: remote,
            bundledCatalog: bundled
        )

        let initial = try await repository.loadCachedOrBundled()
        let refreshed = try await repository.refresh()
        let cached = try await store.load()
        XCTAssertEqual(initial?.templates.first?.slug, "bundled")
        XCTAssertEqual(refreshed?.templates.first?.slug, "remote")
        XCTAssertEqual(cached?.templates.first?.slug, "remote")
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("initium-template-tests-\(UUID().uuidString).json")
    }

    private func makeCatalog(slug: String) -> RoutineTemplateCatalog {
        let templateID = UUID()
        return RoutineTemplateCatalog(
            categories: [],
            templates: [RoutineTemplate(
                id: templateID,
                categoryID: UUID(),
                slug: slug,
                nameFR: slug,
                nameEN: slug,
                descriptionFR: nil,
                descriptionEN: nil,
                icon: nil,
                defaultMarginSeconds: 300,
                sortOrder: 0,
                isActive: true
            )],
            steps: [],
            keywords: []
        )
    }
}

private struct StubRemote: RoutineTemplateRemote {
    let catalog: RoutineTemplateCatalog

    func fetchCatalog() async throws -> RoutineTemplateCatalog {
        catalog
    }
}
