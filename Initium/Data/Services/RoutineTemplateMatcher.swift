import Foundation

struct RoutineTemplateMatcher {
    let minimumScore: Int
    let minimumLeadOverSecondBest: Int

    init(minimumScore: Int = 8, minimumLeadOverSecondBest: Int = 3) {
        self.minimumScore = minimumScore
        self.minimumLeadOverSecondBest = minimumLeadOverSecondBest
    }

    func match(
        title: String,
        location: String? = nil,
        locale: RoutineTemplateLocale,
        catalog: RoutineTemplateCatalog
    ) -> RoutineTemplateMatch? {
        let tokens = Self.tokens(in: [title, location].compactMap { $0 }.joined(separator: " "))
        guard !tokens.isEmpty else { return nil }

        let ranked = catalog.templates.filter(\.isActive).compactMap { template -> RoutineTemplateMatch? in
            let score = catalog
                .keywords(for: template, locale: locale)
                .reduce(0) { partial, keyword in
                    partial + (matches(keyword.keyword, in: tokens) ? max(0, keyword.weight) : 0)
                }

            return score > 0 ? RoutineTemplateMatch(template: template, score: score) : nil
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.template.sortOrder < rhs.template.sortOrder
            }
            return lhs.score > rhs.score
        }

        guard let best = ranked.first, best.score >= minimumScore else { return nil }

        if let second = ranked.dropFirst().first,
           best.score - second.score < minimumLeadOverSecondBest {
            return nil
        }

        return best
    }

    static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    static func tokens(in text: String) -> [String] {
        normalized(text)
            .split { character in
                !character.isLetter && !character.isNumber
            }
            .map(String.init)
    }

    private func matches(_ keyword: String, in textTokens: [String]) -> Bool {
        let keywordTokens = Self.tokens(in: keyword)
        guard !keywordTokens.isEmpty, keywordTokens.count <= textTokens.count else { return false }

        for start in 0...(textTokens.count - keywordTokens.count) {
            let end = start + keywordTokens.count
            if Array(textTokens[start..<end]) == keywordTokens {
                return true
            }
        }

        return false
    }
}
