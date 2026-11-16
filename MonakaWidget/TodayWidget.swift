import SwiftUI
import WidgetKit

/// ホーム画面の大きいウィジェット（systemLarge）。
/// 「今日」画面を縮めたもの：花形の進み具合、未使用時間、今の状態、今週7日分の達成率。
struct TodayEntry: TimelineEntry {
    let date: Date
    let state: FocusWidgetState
    let summary: DailySummary
    let goalMinutes: Int
    let week: [WeekDay]

    struct WeekDay: Identifiable {
        let id: Int
        let label: String
        /// 0〜1。記録がない日・まだ来ていない日は nil
        let rate: Double?
        let isToday: Bool
    }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        let week = ["月", "火", "水", "木", "金", "土", "日"].enumerated().map { i, label in
            TodayEntry.WeekDay(id: i, label: label, rate: i < 4 ? [0.87, 1, 1, 0.76][i] : nil, isToday: i == 3)
        }
        return TodayEntry(
            date: Date(),
            state: .focus(since: Date().addingTimeInterval(-47 * 60)),
            summary: DailySummary(targetMinutes: 340, usedMinutes: 68, longestUnusedMinutes: 125, sessionStarts: []),
            goalMinutes: 360,
            week: week
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    /// 集中タイム中は10分ごとのエントリーを前もって並べ、使わなければ未使用時間が増えていくようにする。
    /// 使用を検知したら検知拡張が再描画を要求するので、そこで作り直される。
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let intervals = FocusSettings.load().intervals(on: now)
        var dates: Set<Date> = [now]
        for interval in intervals {
            dates.insert(interval.range.start)
            dates.insert(interval.range.end)
            var t = max(now, interval.range.start)
            while t < interval.range.end {
                dates.insert(t)
                t = t.addingTimeInterval(10 * 60)
            }
        }
        let entries = dates.filter { $0 >= now }.sorted().map { entry(at: $0) }
        let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60 + 60)
        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }

    private func entry(at date: Date) -> TodayEntry {
        let settings = FocusSettings.load()
        let store = UsageLogStore()
        let events = store.all()
        let calendar = Calendar.current

        func summary(on day: Date, until now: Date) -> DailySummary {
            UsageCalculator.summarize(
                intervals: settings.intervals(on: day),
                events: events.filter { calendar.isDate($0.date, inSameDayAs: day) },
                now: now
            )
        }

        // 月曜始まりの今週
        let today = calendar.startOfDay(for: date)
        let weekdayIndex = (calendar.component(.weekday, from: today) + 5) % 7 // 月=0 … 日=6
        let monday = calendar.date(byAdding: .day, value: -weekdayIndex, to: today) ?? today
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        let week = (0..<7).map { i -> TodayEntry.WeekDay in
            let day = calendar.date(byAdding: .day, value: i, to: monday) ?? monday
            var rate: Double?
            if day <= today, !settings.intervals(on: day).isEmpty {
                let end = day == today ? date : day.addingTimeInterval(24 * 60 * 60)
                rate = summary(on: day, until: end).achievementRate(goalMinutes: settings.goalMinutes)
            }
            return TodayEntry.WeekDay(id: i, label: labels[i], rate: rate, isToday: day == today)
        }

        return TodayEntry(
            date: date,
            state: FocusProvider().entry(at: date).state,
            summary: summary(on: today, until: date),
            goalMinutes: settings.goalMinutes,
            week: week
        )
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry

    private var remaining: Int { max(entry.goalMinutes - entry.summary.unusedMinutes, 0) }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("MONAKA")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                statusChip
            }

            ZStack {
                FlowerRing(progress: entry.summary.achievementRate(goalMinutes: entry.goalMinutes), lineWidth: 10)
                VStack(spacing: 2) {
                    Text("未使用時間")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                    Text(DurationFormat.hm(entry.summary.unusedMinutes))
                        .font(.system(size: 46, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text("目標 \(DurationFormat.hm(entry.goalMinutes)) ・ あと \(DurationFormat.hm(remaining))")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 168, height: 168)

            if case .focus(let since) = entry.state {
                HStack(spacing: 6) {
                    Text("現在")
                    Text(since, style: .timer)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text("使用していません")
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                ForEach(entry.week) { day in
                    VStack(spacing: 4) {
                        ZStack {
                            FlowerRing(progress: day.rate ?? 0, lineWidth: 3)
                        }
                        .frame(width: 30, height: 30)
                        Text(day.label)
                            .font(.caption2.weight(day.isToday ? .semibold : .regular))
                            .foregroundStyle(day.isToday ? Theme.accentBright : Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .containerBackground(for: .widget) { Theme.background }
    }

    @ViewBuilder
    private var statusChip: some View {
        Group {
            switch entry.state {
            case .focus:
                Text("集中タイム中")
            case .free(let until):
                Text("フリータイム ・ \(until, style: .time)まで")
            case .next(let start):
                Text("次の集中タイム \(start, style: .time)から")
            case .none:
                Text("今日の集中タイムは終了")
            }
        }
        .font(.caption2)
        .foregroundStyle(Color(hex: 0xC9D4EC))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(hex: 0x121A2C), in: Capsule())
        .overlay(Capsule().stroke(Color(hex: 0x22324F)))
    }
}

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("今日の集中")
        .description("今日の未使用時間と、今週の達成率を表示します。")
        .supportedFamilies([.systemLarge])
    }
}
