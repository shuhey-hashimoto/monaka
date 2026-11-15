import Foundation

/// 0:00 からの分数で表す時刻。
struct TimeOfDay: Codable, Hashable, Comparable {
    var minutes: Int

    init(minutes: Int) {
        self.minutes = max(0, min(minutes, 24 * 60))
    }

    init(hour: Int, minute: Int = 0) {
        self.init(minutes: hour * 60 + minute)
    }

    var hour: Int { minutes / 60 }
    var minute: Int { minutes % 60 }

    /// 「9:00」「13:30」形式。
    var text: String { "\(hour):" + String(format: "%02d", minute) }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.minutes < rhs.minutes }
}

/// 開始〜終了の時間帯（同じ日の中で完結する）。
struct TimeRange: Codable, Hashable, Identifiable {
    var id = UUID()
    var start: TimeOfDay
    var end: TimeOfDay

    var durationMinutes: Int { max(0, end.minutes - start.minutes) }

    func contains(minute: Int) -> Bool { minute >= start.minutes && minute < end.minutes }
}

/// 1つの曜日の集中タイムとフリータイム。
struct DaySchedule: Codable, Hashable {
    var focus: [TimeRange] = []
    var free: [TimeRange] = []

    /// 集中タイムからフリータイムを除いた「対象区間」。開始時刻順。
    func targetRanges() -> [TimeRange] {
        var result: [TimeRange] = []
        for f in focus.sorted(by: { $0.start < $1.start }) {
            var pieces: [(Int, Int)] = [(f.start.minutes, f.end.minutes)]
            for fr in free {
                pieces = pieces.flatMap { piece -> [(Int, Int)] in
                    let s = max(piece.0, fr.start.minutes)
                    let e = min(piece.1, fr.end.minutes)
                    if s >= e { return [piece] }
                    var out: [(Int, Int)] = []
                    if piece.0 < s { out.append((piece.0, s)) }
                    if e < piece.1 { out.append((e, piece.1)) }
                    return out
                }
            }
            result += pieces
                .filter { $0.0 < $0.1 }
                .map { TimeRange(start: TimeOfDay(minutes: $0.0), end: TimeOfDay(minutes: $0.1)) }
        }
        return result
    }
}

/// その日の対象区間（監視の単位）。id は DeviceActivityName と同じ文字列。
struct TargetInterval: Hashable {
    var id: String
    var range: DateInterval
}

/// 利用者の設定。曜日のキーは Calendar の weekday（1 = 日曜 … 7 = 土曜）。
struct FocusSettings: Codable, Equatable {
    var days: [Int: DaySchedule]
    var goalMinutes: Int
    /// 記録しない日（yyyy-MM-dd）。
    var skipDates: Set<String> = []

    /// OSの制約で、監視区間は15分以上必要。
    static let minimumIntervalMinutes = 15

    static let `default`: FocusSettings = {
        let work = DaySchedule(
            focus: [TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 18))],
            free: [TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13))]
        )
        var days: [Int: DaySchedule] = [:]
        for weekday in 2...6 { days[weekday] = work }
        return FocusSettings(days: days, goalMinutes: 6 * 60)
    }()

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> FocusSettings {
        guard let data = defaults.data(forKey: AppGroup.Key.settings),
              let settings = try? JSONDecoder().decode(FocusSettings.self, from: data)
        else { return .default }
        return settings
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: AppGroup.Key.settings)
        }
    }

    func schedule(on date: Date, calendar: Calendar = .current) -> DaySchedule? {
        guard !isSkipped(date, calendar: calendar) else { return nil }
        return days[calendar.component(.weekday, from: date)]
    }

    func isSkipped(_ date: Date, calendar: Calendar = .current) -> Bool {
        skipDates.contains(Self.dayKey(date, calendar: calendar))
    }

    /// その日の対象区間を日時に直したもの。15分未満の区間は監視できないので含めない。
    func intervals(on date: Date, calendar: Calendar = .current) -> [TargetInterval] {
        guard let day = schedule(on: date, calendar: calendar) else { return [] }
        let weekday = calendar.component(.weekday, from: date)
        let startOfDay = calendar.startOfDay(for: date)
        return day.targetRanges().enumerated().compactMap { index, range in
            guard range.durationMinutes >= Self.minimumIntervalMinutes else { return nil }
            let start = startOfDay.addingTimeInterval(TimeInterval(range.start.minutes * 60))
            let end = startOfDay.addingTimeInterval(TimeInterval(range.end.minutes * 60))
            return TargetInterval(
                id: MonitorNames.activity(weekday: weekday, index: index),
                range: DateInterval(start: start, end: end)
            )
        }
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
