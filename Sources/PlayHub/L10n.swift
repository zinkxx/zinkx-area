import Foundation

// MARK: - Localization
//
// The Turkish UI text is the lookup key. `L("Oyna")` returns the translation for the active
// language from Resources/<code>.lproj/Localizable.strings, or the Turkish text if there is none.
// Interpolations become `%@` placeholders in the key: `L("Hoş geldin, \(name)")` looks up
// "Hoş geldin, %@". Translations may reorder them with `%1$@`, `%2$@`.
// When the first interpolated value is an integer equal to 1, a "<key>##one" entry is preferred
// (singular form for languages that need it).
// Run `scripts/l10n_check.py` after adding or changing L(...) strings.

enum AppLanguage: String, SettingOption {
    case system
    case tr, en, de, fr, es, ja
    case zhHans = "zh-Hans"
    case ko

    var title: String {
        switch self {
        case .system: L("Sistem dili")
        case .tr: "Türkçe"
        case .en: "English"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        case .ja: "日本語"
        case .zhHans: "简体中文"
        case .ko: "한국어"
        }
    }
}

enum L10n {
    /// Codes that have a translation table (Turkish is the source language).
    static let supported = AppLanguage.allCases.filter { $0 != .system }.map(\.rawValue)

    private(set) static var code = "tr"
    private(set) static var locale = Locale(identifier: "tr_TR")
    private static var table: [String: String] = [:]

    static func apply(_ language: AppLanguage) {
        code = language == .system ? systemCode() : language.rawValue
        locale = Locale(identifier: localeIDs[code] ?? code)
        table = loadTable(code)
    }

    /// First macOS preferred language we support; English when none match.
    static func systemCode() -> String {
        for id in Locale.preferredLanguages {
            let lang = Locale(identifier: id).language.languageCode?.identifier ?? ""
            if lang == "zh" { return "zh-Hans" }
            if supported.contains(lang) { return lang }
        }
        return "en"
    }

    static func lookup(_ key: String, count: Int? = nil) -> String {
        if let count, isSingular(count), let one = table[key + "##one"] { return one }
        return table[key] ?? key
    }

    private static func isSingular(_ n: Int) -> Bool {
        code == "fr" ? (n == 0 || n == 1) : n == 1
    }

    private static let localeIDs = [
        "tr": "tr_TR", "en": "en_US", "de": "de_DE", "fr": "fr_FR", "es": "es_ES",
        "ja": "ja_JP", "zh-Hans": "zh_Hans_CN", "ko": "ko_KR",
    ]

    private static func loadTable(_ code: String) -> [String: String] {
        guard code != "tr",
              let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                        subdirectory: nil, localization: code),
              let dict = NSDictionary(contentsOf: url) as? [String: String]
        else { return [:] }
        return dict
    }

    /// Replaces `%@` (in order) and `%N$@` (by position) with the given arguments.
    static func format(_ template: String, _ args: [String]) -> String {
        guard !args.isEmpty else { return template }
        var out = ""
        var next = 0
        var i = template.startIndex
        while i < template.endIndex {
            let c = template[i]
            if c == "%" {
                let rest = template[template.index(after: i)...]
                if rest.hasPrefix("@") {
                    out += next < args.count ? args[next] : ""
                    next += 1
                    i = template.index(i, offsetBy: 2)
                    continue
                }
                let digits = rest.prefix { $0.isNumber }
                if !digits.isEmpty, rest.dropFirst(digits.count).hasPrefix("$@"), let n = Int(digits) {
                    out += (1...args.count).contains(n) ? args[n - 1] : ""
                    i = template.index(i, offsetBy: 1 + digits.count + 2)
                    continue
                }
            }
            out.append(c)
            i = template.index(after: i)
        }
        return out
    }
}

/// A UI string literal whose interpolations are collected as arguments instead of being baked in.
struct LocalizedText: ExpressibleByStringInterpolation {
    let key: String
    let args: [String]
    let count: Int?

    init(stringLiteral value: String) {
        key = value; args = []; count = nil
    }

    init(stringInterpolation i: Interpolation) {
        key = i.key; args = i.args; count = i.count
    }

    struct Interpolation: StringInterpolationProtocol {
        var key = ""
        var args: [String] = []
        var count: Int?

        init(literalCapacity: Int, interpolationCount: Int) {}

        mutating func appendLiteral(_ literal: String) { key += literal }

        mutating func appendInterpolation<T>(_ value: T) {
            if count == nil, let n = value as? any BinaryInteger { count = Int(clamping: n) }
            key += "%@"
            args.append("\(value)")
        }
    }
}

/// Translates a UI string literal (see the notes at the top of this file).
func L(_ text: LocalizedText) -> String {
    L10n.format(L10n.lookup(text.key, count: text.count), text.args)
}

/// Translates a key that is only known at runtime (stored values such as a genre).
func L(key: String) -> String { L10n.lookup(key) }

/// Marks a literal as a translation key without translating it (it is translated where shown).
func LKey(_ key: String) -> String { key }
