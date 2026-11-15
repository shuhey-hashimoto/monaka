import Foundation

/// 時間の長さの表記。アプリ全体で「h:mm」に統一する（例: 2:15、0:47）。
enum DurationFormat {
    static let empty = "-:--"

    static func hm(_ minutes: Int) -> String {
        let m = max(0, minutes)
        return "\(m / 60):" + String(format: "%02d", m % 60)
    }

    static func hm(_ interval: TimeInterval) -> String {
        hm(Int(interval / 60))
    }
}
