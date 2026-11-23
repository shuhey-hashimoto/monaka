import SwiftData
import SwiftUI

/// 「今日」画面（S-02）。
struct TodayView: View {
    /// 「すべて見る」で履歴タブへ移る
    var onShowHistory: () -> Void = {}

    @State private var settings = FocusSettings.load()
    @State private var summary = DailySummary.empty
    @State private var now = Date()
    @Query(sort: \DailyRecord.date, order: .reverse) private var records: [DailyRecord]

    private var progress: Double { summary.achievementRate(goalMinutes: settings.goalMinutes) }
    private var remainingMinutes: Int { max(settings.goalMinutes - summary.unusedMinutes, 0) }

    /// 連続達成日数（今日の達成も含む。今日が未達でもまだ途中なので途切れさせない）
    private var streak: Int {
        DailyStats.streak(
            todayAchieved: summary.targetMinutes > 0 && summary.unusedMinutes >= settings.goalMinutes,
            pastAchievedNewestFirst: records.map(\.achieved)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusChip
                }
                ring
                stats
                recentUses
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .task {
            // 1分ごとに表示を更新する
            while !Task.isCancelled {
                reload()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(now, format: .dateTime.month().day().weekday())
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
            Text("今日")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    /// 今の状態の札（集中タイム中 ・ 18:00まで など）
    private var statusChip: some View {
        let status = TodayStatusLabel.make(settings: settings, now: now)
        return HStack(spacing: 8) {
            Circle()
                .fill(status.isFocus ? Theme.accentBright : Theme.textTertiary)
                .frame(width: 8, height: 8)
            Text(status.text)
                .font(.footnote)
                .foregroundStyle(Color(hex: 0xC9D4EC))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: 0x121A2C), in: Capsule())
        .overlay(Capsule().stroke(Color(hex: 0x22324F)))
    }

    private var ring: some View {
        ZStack {
            FlowerRing(progress: progress, lineWidth: 12)
            VStack(spacing: 2) {
                Text("未使用時間")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text(DurationFormat.hm(summary.unusedMinutes))
                    .font(.system(size: 72, weight: .ultraLight))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text("目標 \(DurationFormat.hm(settings.goalMinutes)) ・ あと \(DurationFormat.hm(remainingMinutes))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 256, height: 256)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatCard(title: "最長連続未使用", value: DurationFormat.hm(summary.longestUnusedMinutes))
            StatCard(title: "使用回数", value: "\(summary.useCount)回")
            StatCard(title: "連続達成", value: "\(streak)日")
        }
    }

    private var recentUses: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近の使用")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button("すべて見る", action: onShowHistory)
                    .font(.footnote)
                    .foregroundStyle(Theme.accentBright)
            }
            if summary.sessionStarts.isEmpty {
                Text("まだ使っていません")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(recent, id: \.start) { use in
                    HStack {
                        Text("\(use.start, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute()) から")
                        Spacer()
                        if let minutes = use.minutes {
                            Text("\(DurationFormat.hm(minutes)) 使用")
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Divider().overlay(Theme.border) }
                }
            }
        }
    }

    /// 新しい順に3件。長さは sessionStarts と同じ順に並んでいる
    private var recent: [RecentUse] {
        let uses = summary.sessionStarts.enumerated().map { index, start in
            RecentUse(start: start, minutes: index < summary.sessionMinutes.count ? summary.sessionMinutes[index] : nil)
        }
        return Array(uses.reversed().prefix(3))
    }

    private struct RecentUse {
        var start: Date
        var minutes: Int?
    }

    private func reload() {
        now = Date()
        settings = FocusSettings.load()
        summary = UsageCalculator.summarize(
            intervals: settings.intervals(on: now),
            events: UsageLogStore().events(on: now),
            now: now
        )
    }
}

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.title2.weight(.light))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
    }
}

#Preview {
    TodayView()
        .modelContainer(DailyStore.container)
}

/// 「今日」画面の札の文言。
struct TodayStatusLabel: Equatable {
    var text: String
    var isFocus: Bool

    static func make(settings: FocusSettings, now: Date, calendar: Calendar = .current) -> TodayStatusLabel {
        guard let day = settings.schedule(on: now, calendar: calendar), !day.focus.isEmpty else {
            return TodayStatusLabel(text: String(localized: "今日の集中タイムはありません"), isFocus: false)
        }
        let minute = Int(now.timeIntervalSince(calendar.startOfDay(for: now)) / 60)
        let focus = day.focus.sorted { $0.start < $1.start }

        if let current = focus.first(where: { $0.contains(minute: minute) }) {
            if let free = day.free.first(where: { $0.contains(minute: minute) }) {
                let end = min(free.end, current.end)
                return TodayStatusLabel(text: String(localized: "フリータイム ・ \(end.text)まで"), isFocus: false)
            }
            return TodayStatusLabel(text: String(localized: "集中タイム中 ・ \(current.end.text)まで"), isFocus: true)
        }
        if let next = focus.first(where: { $0.start.minutes > minute }) {
            return TodayStatusLabel(text: String(localized: "次の集中タイム ・ \(next.start.text)から"), isFocus: false)
        }
        return TodayStatusLabel(text: String(localized: "今日の集中タイムは終わりました"), isFocus: false)
    }
}
