import Foundation
import SwiftData

/// 昨日までの使用ログを日次記録にまとめる（システム要件定義書 4.6 / F-06）。
/// アプリを開いたときに呼ぶ。数日開かなくても、次に開いたときにまとめて処理する。
@MainActor
enum DailyRecorder {
    static func finalize(context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        let settings = FocusSettings.load()
        let store = UsageLogStore()
        let events = store.all()
        let today = calendar.startOfDay(for: now)

        // まとめ始める日：最後の記録の翌日 → 使い始めた日 → いちばん古いログの日
        let records = DailyStore.records(in: context)
        var day: Date
        if let last = records.last?.date, let next = calendar.date(byAdding: .day, value: 1, to: last) {
            day = next
        } else if let start = store.startDate ?? events.map(\.date).min() {
            day = calendar.startOfDay(for: start)
        } else {
            return
        }

        var processed = 0
        while day < today && processed < 366 {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let intervals = settings.intervals(on: day, calendar: calendar)
            if !intervals.isEmpty {
                let dayEvents = events.filter { calendar.isDate($0.date, inSameDayAs: day) }
                let summary = UsageCalculator.summarize(intervals: intervals, events: dayEvents, now: nextDay)
                context.insert(DailyRecord(
                    dayKey: FocusSettings.dayKey(day, calendar: calendar),
                    date: day,
                    summary: summary,
                    goalMinutes: settings.goalMinutes
                ))
            }
            day = nextDay
            processed += 1
        }

        do {
            try context.save()
            store.removeEvents(before: today)
        } catch {
            // 保存できなかったときはログを消さず、次回もう一度まとめる
        }
    }
}

/// 今日の途中経過（今日はまだ日次記録にしていないので、使用ログから計算する）。
struct TodayStatus {
    var summary: DailySummary
    var goalMinutes: Int
    var hasFocusTime: Bool

    var achieved: Bool { summary.unusedMinutes >= goalMinutes }

    static func current(now: Date = Date()) -> TodayStatus {
        let settings = FocusSettings.load()
        let intervals = settings.intervals(on: now)
        let summary = UsageCalculator.summarize(intervals: intervals, events: UsageLogStore().events(on: now), now: now)
        return TodayStatus(summary: summary, goalMinutes: settings.goalMinutes, hasFocusTime: !intervals.isEmpty)
    }
}
