import Foundation

enum InitiumLocalization {
    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(
            key,
            tableName: nil,
            bundle: .main,
            value: key,
            comment: "Initium interface string"
        )

        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
