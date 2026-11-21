import Foundation

/// 連続達成日数などの集計（純粋な計算だけ。テストしやすいよう保存の仕組みとは切り離す）。
enum DailyStats {
    /// 新しい日から順に並べた「目標を達成したか」から、連続達成日数を数える。
    /// 集中タイムのない日（週末・記録しない日）は記録自体がないので、連続は途切れない。
    static func streak(achievedNewestFirst: [Bool]) -> Int {
        var count = 0
        for achieved in achievedNewestFirst {
            guard achieved else { break }
            count += 1
        }
        return count
    }

    /// 今日を含めた連続達成日数。今日は達成していれば1日足し、未達でもまだ途中なので途切れさせない。
    static func streak(todayAchieved: Bool, pastAchievedNewestFirst: [Bool]) -> Int {
        (todayAchieved ? 1 : 0) + streak(achievedNewestFirst: pastAchievedNewestFirst)
    }

    /// 平均（分）。値がなければ nil。
    static func average(_ minutes: [Int]) -> Int? {
        guard !minutes.isEmpty else { return nil }
        return Int((Double(minutes.reduce(0, +)) / Double(minutes.count)).rounded())
    }

    /// 「+1:11」「-0:20」「±0:00」
    static func signedHM(_ minutes: Int) -> String {
        if minutes == 0 { return "±0:00" }
        return (minutes > 0 ? "+" : "-") + DurationFormat.hm(abs(minutes))
    }
}

/// 前の日の終了時サマリーで使う「前回の未使用時間」。検知拡張でも軽く読めるよう UserDefaults に置く。
enum DailySummaryMemo {
    private static let key = "monaka.lastSummary"

    static func save(unusedMinutes: Int, on date: Date, defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(["day": FocusSettings.dayKey(date), "unused": unusedMinutes], forKey: key)
    }

    /// 今日より前に保存した未使用時間（前回集中タイムがあった日）。
    static func previous(before date: Date, defaults: UserDefaults = AppGroup.defaults) -> Int? {
        guard let memo = defaults.dictionary(forKey: key),
              let day = memo["day"] as? String,
              let unused = memo["unused"] as? Int,
              day != FocusSettings.dayKey(date) else { return nil }
        return unused
    }
}
