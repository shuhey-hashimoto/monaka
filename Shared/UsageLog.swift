import Foundation

/// 検知拡張が記録する「区間の開始から累計 N 分使った」という1件の記録。
struct UsageEvent: Codable, Hashable {
    var date: Date
    var intervalID: String
    var cumulativeMinutes: Int
}

/// 使用ログ。共有領域に1行1件のJSONで追記する。
/// 検知拡張のメモリ上限は数MBなので、重い処理はここでしない。
final class UsageLogStore {
    private let fileURL: URL
    private let defaults: UserDefaults

    init(directory: URL = AppGroup.containerURL, defaults: UserDefaults = AppGroup.defaults) {
        self.fileURL = directory.appendingPathComponent("usage-log.jsonl")
        self.defaults = defaults
    }

    func append(_ event: UsageEvent) {
        guard var data = try? JSONEncoder().encode(event) else { return }
        data.append(0x0A) // 改行
        if FileManager.default.fileExists(atPath: fileURL.path),
           let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func all() -> [UsageEvent] {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return text.split(separator: "\n").compactMap { line in
            try? decoder.decode(UsageEvent.self, from: Data(line.utf8))
        }
    }

    func events(on date: Date, calendar: Calendar = .current) -> [UsageEvent] {
        all().filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// 同じ区間・同じ閾値の通知が同じ日に2回来たら無視する（iOS 26系の誤検知対策）。
    func contains(intervalID: String, cumulativeMinutes: Int, on date: Date, calendar: Calendar = .current) -> Bool {
        events(on: date, calendar: calendar).contains {
            $0.intervalID == intervalID && $0.cumulativeMinutes == cumulativeMinutes
        }
    }

    /// 日次記録にまとめ終わった古いログを消す（今日の分は残す）。
    func removeEvents(before date: Date) {
        let kept = all().filter { $0.date >= date }
        let encoder = JSONEncoder()
        var data = Data()
        for event in kept {
            guard let line = try? encoder.encode(event) else { continue }
            data.append(line)
            data.append(0x0A)
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 使い始めた日（初回セットアップを終えた日）。日次記録をまとめ始める日。
    var startDate: Date? {
        get { defaults.object(forKey: AppGroup.Key.startDate) as? Date }
        set { defaults.set(newValue, forKey: AppGroup.Key.startDate) }
    }

    /// 最後に使ったと検知した時刻。ウィジェットの経過時間の起点。
    var lastUseDate: Date? {
        get { defaults.object(forKey: AppGroup.Key.lastUseDate) as? Date }
        set { defaults.set(newValue, forKey: AppGroup.Key.lastUseDate) }
    }
}
