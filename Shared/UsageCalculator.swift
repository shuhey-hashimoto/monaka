import Foundation

/// 1日分の集計結果。
struct DailySummary: Equatable {
    /// これまでの対象時間（分）。進行中の区間は現在時刻まで。
    var targetMinutes: Int
    /// 使用時間（分）。1分単位の近似。
    var usedMinutes: Int
    /// 最長連続未使用（分）。
    var longestUnusedMinutes: Int
    /// 使い始めの時刻（近似：最初の検知の1分前）。
    var sessionStarts: [Date]
    /// それぞれの使用の長さ（分）。sessionStarts と同じ順。日次記録には保存しない（今日の画面だけで使う）
    var sessionMinutes: [Int] = []

    var unusedMinutes: Int { max(targetMinutes - usedMinutes, 0) }
    var useCount: Int { sessionStarts.count }

    func achievementRate(goalMinutes: Int) -> Double {
        guard goalMinutes > 0 else { return 0 }
        return min(Double(unusedMinutes) / Double(goalMinutes), 1)
    }

    static let empty = DailySummary(targetMinutes: 0, usedMinutes: 0, longestUnusedMinutes: 0, sessionStarts: [])
}

/// 使用ログから未使用時間などを計算する（システム要件定義書 4.3）。
enum UsageCalculator {
    /// 検知の間隔がこれ以上空いたら別の「使用」とみなす。
    static let sessionGap: TimeInterval = 120

    static func summarize(intervals: [TargetInterval], events: [UsageEvent], now: Date = Date()) -> DailySummary {
        var target = 0
        var used = 0
        var longest = 0
        var starts: [Date] = []
        var lengths: [Int] = []

        for interval in intervals {
            let range = interval.range
            guard now > range.start else { continue }
            let end = min(now, range.end)
            let intervalMinutes = Int(end.timeIntervalSince(range.start) / 60)
            target += intervalMinutes

            let inInterval = events
                .filter { $0.intervalID == interval.id && $0.date >= range.start && $0.date <= range.end }
                .sorted { $0.date < $1.date }
            used += min(inInterval.map(\.cumulativeMinutes).max() ?? 0, intervalMinutes)

            var lastUsed = range.start
            var previous: Date?
            // 累計分数は区間の初めから数えるので、使用ごとの長さは「前の使用の終わりの累計」との差になる
            var cumulativeBefore = 0
            var cumulative = 0
            for event in inInterval {
                if let previous, event.date.timeIntervalSince(previous) < sessionGap {
                    // 同じ使用の続き
                } else {
                    if previous != nil {
                        // 直前の使用を締める
                        lengths.append(max(cumulative - cumulativeBefore, 1))
                        cumulativeBefore = cumulative
                    }
                    let start = max(range.start, event.date.addingTimeInterval(-60))
                    starts.append(start)
                    longest = max(longest, Int(start.timeIntervalSince(lastUsed) / 60))
                }
                cumulative = max(cumulative, event.cumulativeMinutes)
                previous = event.date
                lastUsed = event.date
            }
            if previous != nil {
                lengths.append(max(cumulative - cumulativeBefore, 1))
            }
            longest = max(longest, Int(end.timeIntervalSince(lastUsed) / 60))
        }

        return DailySummary(
            targetMinutes: target,
            usedMinutes: min(used, target),
            longestUnusedMinutes: longest,
            sessionStarts: starts,
            sessionMinutes: lengths
        )
    }

    /// このまま使わなければ未使用時間が目標に届く時刻。今日の残りの区間では届かない、または達成済みなら nil。
    static func dateReachingGoal(intervals: [TargetInterval], unusedMinutes: Int, goalMinutes: Int, now: Date = Date()) -> Date? {
        var remaining = TimeInterval((goalMinutes - unusedMinutes) * 60)
        guard remaining > 0 else { return nil }
        for interval in intervals.sorted(by: { $0.range.start < $1.range.start }) {
            let start = max(now, interval.range.start)
            guard start < interval.range.end else { continue }
            let available = interval.range.end.timeIntervalSince(start)
            if available >= remaining { return start.addingTimeInterval(remaining) }
            remaining -= available
        }
        return nil
    }
}
