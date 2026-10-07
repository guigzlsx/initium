import Foundation

struct SupabaseConfiguration: Sendable {
    let projectURL: URL
    let anonKey: String

    static func fromBundle(_ bundle: Bundle = .main) -> Self? {
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let projectURL = URL(string: urlString),
            projectURL.scheme == "https",
            projectURL.host != nil,
            let anonKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !anonKey.isEmpty,
            !anonKey.contains("$(")
        else {
            return nil
        }

        return Self(projectURL: projectURL, anonKey: anonKey)
    }
}

enum RoutineTemplateRepositoryError: LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Le catalogue de préparations est momentanément indisponible."
        case .httpStatus(let status):
            return "Le catalogue de préparations a répondu avec le statut \(status)."
        case .invalidConfiguration:
            return "La configuration du catalogue de préparations est invalide."
        }
    }
}

protocol RoutineTemplateRemote {
    func fetchCatalog() async throws -> RoutineTemplateCatalog
}

struct SupabaseTemplateRemote: RoutineTemplateRemote {
    private let configuration: SupabaseConfiguration
    private let session: URLSession

    init(configuration: SupabaseConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func fetchCatalog() async throws -> RoutineTemplateCatalog {
        async let categories: [RoutineTemplateCategory] = fetch(
            RoutineTemplateCategory.self,
            path: "routine_template_categories",
            select: "id,slug,name_fr,name_en,icon,sort_order,is_active",
            order: "sort_order.asc"
        )
        async let templates: [RoutineTemplate] = fetch(
            RoutineTemplate.self,
            path: "routine_templates",
            select: "id,category_id,slug,name_fr,name_en,description_fr,description_en,icon,default_margin_seconds,sort_order,is_active",
            order: "sort_order.asc"
        )
        async let steps: [RoutineTemplateStep] = fetch(
            RoutineTemplateStep.self,
            path: "routine_template_steps",
            select: "id,template_id,step_key,title_fr,title_en,estimated_duration_seconds,sort_order,is_optional,is_active",
            order: "sort_order.asc"
        )
        async let keywords: [RoutineTemplateKeyword] = fetch(
            RoutineTemplateKeyword.self,
            path: "routine_template_keywords",
            select: "id,template_id,locale,keyword,weight",
            includeActiveFilter: false,
            order: "keyword.asc"
        )

        return RoutineTemplateCatalog(
            categories: try await categories,
            templates: try await templates,
            steps: try await steps,
            keywords: try await keywords
        )
    }

    private func fetch<T: Decodable>(
        _ type: T.Type,
        path: String,
        select: String,
        includeActiveFilter: Bool = true,
        order: String
    ) async throws -> [T] {
        var components = URLComponents(
            url: configuration.projectURL.appendingPathComponent("rest/v1/\(path)"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [URLQueryItem(name: "select", value: select)]
        if includeActiveFilter {
            queryItems.append(URLQueryItem(name: "is_active", value: "eq.true"))
        }
        queryItems.append(URLQueryItem(name: "order", value: order))
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw RoutineTemplateRepositoryError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoutineTemplateRepositoryError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RoutineTemplateRepositoryError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode([T].self, from: data)
    }
}

actor RoutineTemplateCacheStore {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.fileURL = baseURL
                .appendingPathComponent("Initium", isDirectory: true)
                .appendingPathComponent("routine-template-catalog.json")
        }
    }

    func load() throws -> RoutineTemplateCatalog? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(RoutineTemplateCatalog.self, from: data)
    }

    func save(_ catalog: RoutineTemplateCatalog) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(catalog)
        try data.write(to: fileURL, options: .atomic)
    }
}

final class RoutineTemplateRepository {
    private let cache: RoutineTemplateCacheStore
    private let remote: (any RoutineTemplateRemote)?
    private let bundledCatalog: RoutineTemplateCatalog?

    var isRemoteConfigured: Bool { remote != nil }

    init(
        cache: RoutineTemplateCacheStore = RoutineTemplateCacheStore(),
        remote: (any RoutineTemplateRemote)? = SupabaseConfiguration.fromBundle().map {
            SupabaseTemplateRemote(configuration: $0)
        },
        bundledCatalog: RoutineTemplateCatalog? = RoutineTemplateRepository.loadBundledCatalog()
    ) {
        self.cache = cache
        self.remote = remote
        self.bundledCatalog = bundledCatalog
    }

    func loadCachedOrBundled() async throws -> RoutineTemplateCatalog? {
        if let cached = try await cache.load() {
            return cached
        }

        guard let bundledCatalog else { return nil }
        try? await cache.save(bundledCatalog)
        return bundledCatalog
    }

    func refresh() async throws -> RoutineTemplateCatalog? {
        guard let remote else { return nil }
        let catalog = try await remote.fetchCatalog()
        try await cache.save(catalog)
        return catalog
    }

    private static func loadBundledCatalog() -> RoutineTemplateCatalog? {
        guard let url = Bundle.main.url(forResource: "routine_templates_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(RoutineTemplateCatalog.self, from: data)
    }
}

@MainActor
final class RoutineTemplateCatalogViewModel: ObservableObject {
    @Published private(set) var catalog: RoutineTemplateCatalog = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshFailed = false

    private let repository: RoutineTemplateRepository

    init(repository: RoutineTemplateRepository = RoutineTemplateRepository()) {
        self.repository = repository
    }

    func loadAndRefresh() async {
        if let initial = try? await repository.loadCachedOrBundled() {
            catalog = initial
        }

        guard repository.isRemoteConfigured else { return }

        isRefreshing = true
        lastRefreshFailed = false
        defer { isRefreshing = false }

        do {
            if let refreshed = try await repository.refresh() {
                catalog = refreshed
            }
        } catch {
            lastRefreshFailed = true
        }
    }

    func match(for activity: Activity, locale: RoutineTemplateLocale = .current) -> RoutineTemplateMatch? {
        guard activity.routine == nil, !activity.externalIsAllDay, !activity.isExternallyDeleted else {
            return nil
        }

        return RoutineTemplateMatcher().match(
            title: activity.title,
            location: activity.externalLocation,
            locale: locale,
            catalog: catalog
        )
    }
}
