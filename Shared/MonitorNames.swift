import Foundation

/// スクリーンタイムの監視（DeviceActivity）で使う名前の決まり。
/// アプリ本体（登録側）と検知拡張（受け取り側）で同じ規則を使う。
enum MonitorNames {
    /// 対象区間ごとの監視名。例: monaka.w2.i0（月曜の1つ目の区間）
    static func activity(weekday: Int, index: Int) -> String {
        "monaka.w\(weekday).i\(index)"
    }

    static let usedPrefix = "monaka.used."

    /// 「区間の開始から累計 N 分使った」イベント名。
    static func usedEvent(minutes: Int) -> String {
        usedPrefix + String(minutes)
    }

    static func minutes(fromEvent raw: String) -> Int? {
        guard raw.hasPrefix(usedPrefix) else { return nil }
        return Int(raw.dropFirst(usedPrefix.count))
    }

    /// 1区間に登録するイベント数の上限。OS側の上限は未確認（PoCで確認する）。
    static let maxEventsPerInterval = 600
}
