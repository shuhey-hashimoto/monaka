import SwiftUI

/// 「今日」画面（S-02）。
struct TodayView: View {
    @State private var settings = FocusSettings.load()
    @State private var summary = DailySummary.empty
    @State private var now = Date()

    private var progress: Double { summary.achievementRate(goalMinutes: settings.goalMinutes) }
    private var remainingMinutes: Int { max(settings.goalMinutes - summary.unusedMinutes, 0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
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
            // TODO: 日次記録の保存（F-06）ができたら連続達成日数を出す
            StatCard(title: "連続達成", value: "-日")
        }
    }

    private var recentUses: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("最近の使用")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textTertiary)
            if summary.sessionStarts.isEmpty {
                Text("まだ使っていません")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(summary.sessionStarts.reversed().prefix(3)), id: \.self) { start in
                    HStack {
                        Text("\(start, format: .dateTime.hour().minute()) から")
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Divider().overlay(Theme.border) }
                }
            }
        }
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
}
