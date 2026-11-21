import Foundation

/// アプリ本体・検知拡張・ウィジェットが共有する保存場所（App Group）。
/// グループIDは Config/Base.xcconfig の APP_GROUP_ID から各 Info.plist 経由で渡される。
enum AppGroup {
    static let identifier: String =
        (Bundle.main.object(forInfoDictionaryKey: "MonakaAppGroupID") as? String)
        ?? "group.com.example.monaka"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.temporaryDirectory
    }

    enum Key {
        static let settings = "monaka.settings"
        static let lastUseDate = "monaka.lastUseDate"
        static let startDate = "monaka.startDate"
    }
}
