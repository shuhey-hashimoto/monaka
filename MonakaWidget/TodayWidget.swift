import SwiftData
import SwiftUI
import WidgetKit

/// 「今日の集中」ウィジェット。大きさごとに見せる量を変える。
/// - 小：花形と未使用時間だけ（StandBy でも使える）
/// - 中：花形と未使用時間、今の状態、目標までの残り、連続達成日数
/// - 大：「今日」画面を縮めたもの。今週7日分の達成率つき
/// - ロック画面の丸：小さな花形と未使用時間
struct TodayEntry: TimelineEntry {
    let date: Date
    let state: FocusWidgetState
    let summary: DailySummary
    let goalMinutes: Int
    let week: [WeekDay]
    /// 今日を含めた連続達成日数（今日が未達でも途中なので途切れさせない）
    let streak: Int

    struct WeekDay: Identifiable {
        let id: Int
        let label: String
        /// 0〜1。記録がない日・まだ来ていない日は nil
        let rate: Double?
        /// その日の未使用時間。記録がない日・まだ来ていない日は nil
        let unusedMinutes: Int?
        let isToday: Bool
        let achieved: Bool
    }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        let week = ["月", "火", "水", "木", "金", "土", "日"].enumerated().map { i, label in
            TodayEntry.WeekDay(
                id: i, label: label,
                rate: i < 4 ? [0.87, 1, 1, 0.76][i] : nil,
                unusedMinutes: i < 4 ? [312, 391, 365, 272][i] : nil,
                isToday: i == 3,
                achieved: i == 1 || i == 2
            )
        }
        return TodayEntry(
            date: Date(),
            state: .focus(since: Date().addingTimeInterval(-47 * 60)),
            summary: DailySummary(targetMinutes: 340, usedMinutes: 68, longestUnusedMinutes: 125, sessionStarts: []),
            goalMinutes: 360,
            week: week,
            streak: 4
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
        // 昨日までは日次記録から読む（まとめ終わった使用ログは消えているため）
        let records = DailyStore.records(in: ModelContext(DailyStore.container))
        let recordsByKey = Dictionary(
            records.map { ($0.dayKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let week = (0..<7).map { i -> TodayEntry.WeekDay in
            let day = calendar.date(byAdding: .day, value: i, to: monday) ?? monday
            var rate: Double?
            var unused: Int?
            var achieved = false
            if day < today, let record = recordsByKey[FocusSettings.dayKey(day)] {
                rate = record.achievementRate
                unused = record.unusedMinutes
                achieved = record.achieved
            } else if day <= today, !settings.intervals(on: day).isEmpty {
                let end = day == today ? date : day.addingTimeInterval(24 * 60 * 60)
                let s = summary(on: day, until: end)
                rate = s.achievementRate(goalMinutes: settings.goalMinutes)
                unused = s.unusedMinutes
                achieved = settings.goalMinutes > 0 && s.unusedMinutes >= settings.goalMinutes
            }
            return TodayEntry.WeekDay(
                id: i, label: labels[i], rate: rate, unusedMinutes: unused,
                isToday: day == today, achieved: achieved
            )
        }

        let todaySummary = summary(on: today, until: date)
        let streak = DailyStats.streak(
            todayAchieved: settings.goalMinutes > 0 && todaySummary.unusedMinutes >= settings.goalMinutes,
            pastAchievedNewestFirst: records.filter { $0.date < today }.reversed().map(\.achieved)
        )

        return TodayEntry(
            date: date,
            state: FocusProvider().entry(at: date).state,
            summary: todaySummary,
            goalMinutes: settings.goalMinutes,
            week: week,
            streak: streak
        )
    }
}

/// 大きさで見た目を切り替える。
struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch family {
        case .systemSmall:
            TodaySmallView(entry: entry)
        case .systemMedium:
            TodayMediumView(entry: entry)
        case .accessoryCircular:
            TodayCircularView(entry: entry)
        default:
            TodayLargeView(entry: entry)
        }
    }
}

extension TodayEntry {
    var rate: Double { summary.achievementRate(goalMinutes: goalMinutes) }
    var remainingMinutes: Int { max(goalMinutes - summary.unusedMinutes, 0) }
}

// MARK: - 小

struct TodaySmallView: View {
    let entry: TodayEntry
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var palette: WidgetPalette { WidgetPalette(renderingMode) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                FlowerRing(progress: entry.rate, lineWidth: 7, trackColor: palette.track, accentable: true)
                VStack(spacing: 0) {
                    Text("未使用")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                    Text(DurationFormat.hm(entry.summary.unusedMinutes))
                        .font(.system(size: 30, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .frame(width: 112, height: 112)

            Text("目標 \(DurationFormat.hm(entry.goalMinutes))")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .containerBackground(for: .widget) { Theme.background }
    }
}

// MARK: - 中

struct TodayMediumView: View {
    let entry: TodayEntry
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var palette: WidgetPalette { WidgetPalette(renderingMode) }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                FlowerRing(progress: entry.rate, lineWidth: 8, trackColor: palette.track, accentable: true)
                VStack(spacing: 0) {
                    Text("未使用時間")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                    Text(DurationFormat.hm(entry.summary.unusedMinutes))
                        .font(.system(size: 32, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .frame(width: 122, height: 122)

            VStack(alignment: .leading, spacing: 8) {
                StatusChip(state: entry.state)

                if case .focus(let since) = entry.state {
                    NowUnusedText(since: since)
                        .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                row(title: "目標まで", value: entry.remainingMinutes == 0 ? "達成" : "あと \(DurationFormat.hm(entry.remainingMinutes))")
                row(title: "連続達成", value: "\(entry.streak)日")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { Theme.background }
    }

    private func row(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .font(.footnote)
    }
}

// MARK: - ロック画面の丸

struct TodayCircularView: View {
    let entry: TodayEntry

    var body: some View {
        ZStack {
            FlowerRing(progress: entry.rate, lineWidth: 3.5, color: .white, trackColor: .white.opacity(0.25))
                .widgetAccentable()
            Text(DurationFormat.hm(entry.summary.unusedMinutes))
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 6)
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }
}

// MARK: - 大

struct TodayLargeView: View {
    let entry: TodayEntry
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var palette: WidgetPalette { WidgetPalette(renderingMode) }

    /// 今週の昨日までで、集中タイムがあった日
    private var pastDays: [TodayEntry.WeekDay] {
        entry.week.filter { !$0.isToday && $0.unusedMinutes != nil }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("MONAKA")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                StatusChip(state: entry.state)
            }

            HStack(spacing: 16) {
                ZStack {
                    FlowerRing(progress: entry.rate, lineWidth: 9, trackColor: palette.track, accentable: true)
                    VStack(spacing: 0) {
                        Text("未使用時間")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                        Text(DurationFormat.hm(entry.summary.unusedMinutes))
                            .font(.system(size: 38, weight: .semibold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(Theme.textPrimary)
                        Text("目標 \(DurationFormat.hm(entry.goalMinutes))")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 136, height: 136)

                VStack(spacing: 0) {
                    stat("目標まで", entry.remainingMinutes == 0 ? "達成" : "あと \(DurationFormat.hm(entry.remainingMinutes))")
                    divider
                    stat("最長連続未使用", DurationFormat.hm(entry.summary.longestUnusedMinutes))
                    divider
                    stat("使用回数", "\(entry.summary.useCount)回")
                    divider
                    stat("連続達成", "\(entry.streak)日")
                }
                .frame(maxWidth: .infinity)
            }

            if case .focus(let since) = entry.state {
                NowUnusedText(since: since)
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.border))
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                HStack {
                    Text("今週")
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if let average = DailyStats.average(pastDays.compactMap(\.unusedMinutes)) {
                        Text("平均 \(DurationFormat.hm(average)) ・ 達成 \(pastDays.filter(\.achieved).count)/\(pastDays.count)日")
                            .monospacedDigit()
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .font(.caption2)

                HStack(spacing: 0) {
                    ForEach(entry.week) { day in
                        VStack(spacing: 3) {
                            FlowerRing(progress: day.rate ?? 0, lineWidth: 3, trackColor: palette.track, accentable: true)
                                .frame(width: 30, height: 30)
                            Text(day.label)
                                .font(.caption2.weight(day.isToday ? .semibold : .regular))
                                .foregroundStyle(day.isToday ? Theme.accentBright : Theme.textTertiary)
                                .widgetAccentable(day.isToday)
                            Text(day.unusedMinutes.map { DurationFormat.hm($0) } ?? DurationFormat.empty)
                                .font(.system(size: 9))
                                .monospacedDigit()
                                .foregroundStyle(day.unusedMinutes == nil ? Theme.textTertiary.opacity(0.6) : Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .containerBackground(for: .widget) { Theme.background }
    }

    private var divider: some View {
        Rectangle().fill(palette.border).frame(height: 1)
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 4)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .font(.footnote)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.vertical, 7)
    }
}

/// 「現在 0:47 使用していません」。
/// 経過時間の Text を単独で並べると、幅いっぱいに広がって前後の文字が両端に離れてしまう。
/// 1つの Text にまとめて、中身の幅で真ん中にそろえる。
struct NowUnusedText: View {
    let since: Date

    var body: some View {
        Text("現在 \(Text(since, style: .timer).fontWeight(.semibold).foregroundStyle(Theme.textPrimary)) 使用していません")
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
    }
}

/// ホーム画面のカスタマイズで「色合い調整」や「クリア」を選ぶと、ウィジェットは色を失い白の濃淡だけで描かれる。
/// 不透明な暗い地もまっ白になって文字が読めなくなるので、その場合は白の半透明に切り替える。
struct WidgetPalette {
    let isFullColor: Bool

    init(_ mode: WidgetRenderingMode) {
        isFullColor = mode == .fullColor
    }

    var track: Color { isFullColor ? Theme.track : .white.opacity(0.18) }
    var chipFill: Color { isFullColor ? Color(hex: 0x121A2C) : .white.opacity(0.12) }
    var chipStroke: Color { isFullColor ? Color(hex: 0x22324F) : .white.opacity(0.25) }
    var surface: Color { isFullColor ? Theme.surface : .white.opacity(0.10) }
    var border: Color { isFullColor ? Theme.border : .white.opacity(0.18) }
}

/// 今の状態（集中タイム中・フリータイムなど）の小さな札。中・大で使う。
struct StatusChip: View {
    let state: FocusWidgetState
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var palette: WidgetPalette { WidgetPalette(renderingMode) }

    var body: some View {
        Group {
            switch state {
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
        .background(palette.chipFill, in: Capsule())
        .overlay(Capsule().stroke(palette.chipStroke))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("今日の集中")
        .description("今日の未使用時間と、目標までの進み具合を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular])
    }
}
