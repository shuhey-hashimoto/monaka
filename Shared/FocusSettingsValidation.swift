import Foundation

extension FocusSettings {
    /// 1週間に登録できる監視区間の上限。OS側の上限は未確認のため、PoCで確認して調整する。
    static let maxIntervalsPerWeek = 20

    /// 保存できない設定なら、その理由を返す。
    var validationError: String? {
        var intervalCount = 0
        for weekday in days.keys.sorted() {
            guard let day = days[weekday] else { continue }
            for range in day.focus + day.free where range.end <= range.start {
                return String(localized: "終了時刻は開始時刻より後にしてください。")
            }
            for range in day.targetRanges() {
                if range.durationMinutes < Self.minimumIntervalMinutes {
                    return String(localized: "15分より短い区間は設定できません。集中タイムかフリータイムを調整してください。")
                }
                intervalCount += 1
            }
        }
        if intervalCount > Self.maxIntervalsPerWeek {
            return String(localized: "集中タイムの区間が多すぎます（1週間で\(Self.maxIntervalsPerWeek)区間まで）。")
        }
        if goalMinutes <= 0 {
            return String(localized: "1日の目標時間を設定してください。")
        }
        return nil
    }
}

extension DaySchedule {
    /// 記録の対象になる合計時間（分）。
    var targetMinutes: Int {
        targetRanges().reduce(0) { $0 + $1.durationMinutes }
    }

    /// 次に追加する区間の初期値：最後の区間の終わりから1時間。
    static func nextRange(after ranges: [TimeRange]) -> TimeRange {
        let lastEnd = ranges.map(\.end).max()?.minutes ?? 9 * 60
        let start = lastEnd >= 23 * 60 ? 9 * 60 : lastEnd
        return TimeRange(start: TimeOfDay(minutes: start), end: TimeOfDay(minutes: min(start + 60, 24 * 60)))
    }
}
