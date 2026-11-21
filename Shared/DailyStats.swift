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

// MARK: - ストリークの節目・自己ベスト（N-09）

/// 1日を締めたときの連続達成日数と自己ベスト。検知拡張から軽く読めるよう UserDefaults に置く。
/// 日次記録（SwiftData）は拡張機能のメモリ上限が厳しいので開かず、アプリを開いたときに記録から合わせ直す。
struct MilestoneMemo: Codable, Equatable {
    /// 最後に締めた日（yyyy-MM-dd）
    var dayKey: String
    /// その日の終わり時点の連続達成日数
    var streak: Int
    /// これまでで一番長い未使用時間（分）
    var bestUnusedMinutes: Int
}

enum Milestones {
    /// 通知する節目の日数。100日を超えたら100日ごと。
    static let days: Set<Int> = [3, 7, 14, 30, 60, 100]

    static func isMilestone(_ streak: Int) -> Bool {
        days.contains(streak) || (streak > 100 && streak % 100 == 0)
    }

    struct DayEnd: Equatable {
        var memo: MilestoneMemo
        /// 節目に届いたときの連続達成日数
        var milestoneStreak: Int?
        /// 自己ベストを更新したときの未使用時間
        var newBestMinutes: Int?
    }

    /// その日の最後の区間が終わったときに呼ぶ。同じ日を2回締めたときは nil。
    /// - Parameter previousFocusDayKey: 前に集中タイムがあった日。メモがその日を締めていれば連続をつなぐ。
    static func closeDay(
        memo: MilestoneMemo?,
        dayKey: String,
        previousFocusDayKey: String?,
        unusedMinutes: Int,
        goalMinutes: Int
    ) -> DayEnd? {
        if memo?.dayKey == dayKey { return nil }
        let base = (memo != nil && memo?.dayKey == previousFocusDayKey) ? (memo?.streak ?? 0) : 0
        let achieved = goalMinutes > 0 && unusedMinutes >= goalMinutes
        let streak = achieved ? base + 1 : 0
        let previousBest = memo?.bestUnusedMinutes ?? 0
        // 使い始めの日は比べる相手がいないので、自己ベストとは言わない
        let newBest = (previousBest > 0 && unusedMinutes > previousBest) ? unusedMinutes : nil

        return DayEnd(
            memo: MilestoneMemo(dayKey: dayKey, streak: streak, bestUnusedMinutes: max(previousBest, unusedMinutes)),
            milestoneStreak: (achieved && isMilestone(streak)) ? streak : nil,
            newBestMinutes: newBest
        )
    }

    /// アプリを開いたとき、日次記録から数えた値でメモを合わせ直す。
    /// 今日をもう締めていれば（記録より新しければ）連続はそのまま、自己ベストだけ大きいほうにする。
    static func reconciled(
        memo: MilestoneMemo?,
        lastRecordDayKey: String,
        streakThroughLastRecord: Int,
        bestFromRecords: Int
    ) -> MilestoneMemo {
        let best = max(memo?.bestUnusedMinutes ?? 0, bestFromRecords)
        if let memo, memo.dayKey > lastRecordDayKey {
            return MilestoneMemo(dayKey: memo.dayKey, streak: memo.streak, bestUnusedMinutes: best)
        }
        return MilestoneMemo(dayKey: lastRecordDayKey, streak: streakThroughLastRecord, bestUnusedMinutes: best)
    }

    /// 通知の文面。どちらもなければ nil。
    static func text(milestoneStreak: Int?, newBestMinutes: Int?) -> String? {
        var lines: [String] = []
        if let streak = milestoneStreak {
            lines.append(String(localized: "\(streak)日連続で目標を達成しました"))
        }
        if let best = newBestMinutes {
            lines.append(String(localized: "これまでで一番長い未使用時間です（\(DurationFormat.hm(best))）"))
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// 前に集中タイムがあった日（記録しない日・週末は飛ばす）。1年さかのぼって見つからなければ nil。
    static func previousFocusDay(before date: Date, settings: FocusSettings, calendar: Calendar = .current) -> Date? {
        var day = calendar.startOfDay(for: date)
        for _ in 0..<366 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return nil }
            day = previous
            if !settings.intervals(on: day, calendar: calendar).isEmpty { return day }
        }
        return nil
    }
}

enum MilestoneMemoStore {
    private static let key = "monaka.milestone"

    static func load(defaults: UserDefaults = AppGroup.defaults) -> MilestoneMemo? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MilestoneMemo.self, from: data)
    }

    static func save(_ memo: MilestoneMemo, defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(memo) else { return }
        defaults.set(data, forKey: key)
    }
}
