import Foundation

enum RoutineTemplateLocale: String, Codable, Sendable {
    case fr
    case en

    static var current: Self {
        Locale.current.language.languageCode?.identifier == "fr" ? .fr : .en
    }
}

struct RoutineTemplateCategory: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let slug: String
    let nameFR: String
    let nameEN: String
    let icon: String
    let sortOrder: Int
    let isActive: Bool

    func localizedName(for locale: RoutineTemplateLocale) -> String {
        locale == .fr ? nameFR : nameEN
    }

    enum CodingKeys: String, CodingKey {
        case id, slug, nameFR = "name_fr", nameEN = "name_en", icon
        case sortOrder = "sort_order", isActive = "is_active"
    }
}

struct RoutineTemplate: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let categoryID: UUID
    let slug: String
    let nameFR: String
    let nameEN: String
    let descriptionFR: String?
    let descriptionEN: String?
    let icon: String?
    let defaultMarginSeconds: Int
    let sortOrder: Int
    let isActive: Bool

    func localizedName(for locale: RoutineTemplateLocale) -> String {
        locale == .fr ? nameFR : nameEN
    }

    func localizedDescription(for locale: RoutineTemplateLocale) -> String? {
        locale == .fr ? descriptionFR : descriptionEN
    }

    enum CodingKeys: String, CodingKey {
        case id
        case categoryID = "category_id"
        case slug
        case nameFR = "name_fr"
        case nameEN = "name_en"
        case descriptionFR = "description_fr"
        case descriptionEN = "description_en"
        case icon
        case defaultMarginSeconds = "default_margin_seconds"
        case sortOrder = "sort_order"
        case isActive = "is_active"
    }
}

struct RoutineTemplateStep: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let templateID: UUID
    let stepKey: String
    let titleFR: String
    let titleEN: String
    let estimatedDurationSeconds: Int
    let sortOrder: Int
    let isOptional: Bool
    let isActive: Bool

    func localizedTitle(for locale: RoutineTemplateLocale) -> String {
        locale == .fr ? titleFR : titleEN
    }

    enum CodingKeys: String, CodingKey {
        case id
        case templateID = "template_id"
        case stepKey = "step_key"
        case titleFR = "title_fr"
        case titleEN = "title_en"
        case estimatedDurationSeconds = "estimated_duration_seconds"
        case sortOrder = "sort_order"
        case isOptional = "is_optional"
        case isActive = "is_active"
    }
}

struct RoutineTemplateKeyword: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let templateID: UUID
    let locale: String
    let keyword: String
    let weight: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateID = "template_id"
        case locale, keyword, weight
    }
}

struct RoutineTemplateCatalog: Codable, Hashable, Sendable {
    let categories: [RoutineTemplateCategory]
    let templates: [RoutineTemplate]
    let steps: [RoutineTemplateStep]
    let keywords: [RoutineTemplateKeyword]

    static let empty = RoutineTemplateCatalog(
        categories: [],
        templates: [],
        steps: [],
        keywords: []
    )

    func template(for slug: String) -> RoutineTemplate? {
        templates.first { $0.slug == slug && $0.isActive }
    }

    func steps(for template: RoutineTemplate) -> [RoutineTemplateStep] {
        steps
            .filter { $0.templateID == template.id && $0.isActive }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func keywords(for template: RoutineTemplate, locale: RoutineTemplateLocale) -> [RoutineTemplateKeyword] {
        keywords.filter {
            $0.templateID == template.id &&
            ($0.locale == locale.rawValue || $0.locale == "all")
        }
    }
}

struct RoutineTemplateMatch: Hashable, Sendable {
    let template: RoutineTemplate
    let score: Int
}
