import XCTest
@testable import Initium

final class RoutineTemplateMatcherTests: XCTestCase {
    func testMatchesFrenchTitleWithDiacritics() {
        let restaurant = makeTemplate(slug: "restaurant", name: "Sortir")
        let catalog = makeCatalog(
            templates: [restaurant],
            keywords: [
                makeKeyword(templateID: restaurant.id, keyword: "restaurant", weight: 10),
                makeKeyword(templateID: restaurant.id, keyword: "dîner", weight: 8)
            ]
        )

        let match = RoutineTemplateMatcher().match(
            title: "Dîner au RESTAURANT",
            locale: .fr,
            catalog: catalog
        )

        XCTAssertEqual(match?.template.slug, "restaurant")
        XCTAssertEqual(match?.score, 18)
    }

    func testUsesLocationAsAnAdditionalSignal() {
        let gym = makeTemplate(slug: "gym", name: "Sport")
        let catalog = makeCatalog(
            templates: [gym],
            keywords: [makeKeyword(templateID: gym.id, keyword: "salle de sport", weight: 12)]
        )

        let match = RoutineTemplateMatcher().match(
            title: "Séance",
            location: "Salle de sport",
            locale: .fr,
            catalog: catalog
        )

        XCTAssertEqual(match?.template.slug, "gym")
    }

    func testRejectsLowScoreAndAmbiguousMatches() {
        let quickLeave = makeTemplate(slug: "quick_leave", name: "Sortie")
        let lowScoreCatalog = makeCatalog(
            templates: [quickLeave],
            keywords: [makeKeyword(templateID: quickLeave.id, keyword: "sortir", weight: 6)]
        )
        XCTAssertNil(RoutineTemplateMatcher().match(title: "Sortir", locale: .fr, catalog: lowScoreCatalog))

        let one = makeTemplate(slug: "one", name: "Un")
        let two = makeTemplate(slug: "two", name: "Deux")
        let ambiguousCatalog = makeCatalog(
            templates: [one, two],
            keywords: [
                makeKeyword(templateID: one.id, keyword: "rendez-vous", weight: 10),
                makeKeyword(templateID: two.id, keyword: "rendez-vous", weight: 10)
            ]
        )
        XCTAssertNil(RoutineTemplateMatcher().match(title: "Rendez-vous", locale: .fr, catalog: ambiguousCatalog))
    }

    private func makeCatalog(
        templates: [RoutineTemplate],
        keywords: [RoutineTemplateKeyword]
    ) -> RoutineTemplateCatalog {
        RoutineTemplateCatalog(
            categories: [],
            templates: templates,
            steps: [],
            keywords: keywords
        )
    }

    private func makeTemplate(slug: String, name: String) -> RoutineTemplate {
        let id = UUID()
        return RoutineTemplate(
            id: id,
            categoryID: UUID(),
            slug: slug,
            nameFR: name,
            nameEN: name,
            descriptionFR: nil,
            descriptionEN: nil,
            icon: nil,
            defaultMarginSeconds: 300,
            sortOrder: 0,
            isActive: true
        )
    }

    private func makeKeyword(templateID: UUID, keyword: String, weight: Int) -> RoutineTemplateKeyword {
        return RoutineTemplateKeyword(
            id: UUID(),
            templateID: templateID,
            locale: "fr",
            keyword: keyword,
            weight: weight
        )
    }
}
