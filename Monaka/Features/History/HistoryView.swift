import SwiftData
import SwiftUI

/// 履歴画面（S-03）：月カレンダーに花形の達成率と未使用時間を並べる。
struct HistoryView: View {
    @Query(sort: \DailyRecord.date) private var records: [DailyRecord]

    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var today = TodayStatus.current()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var recordsByKey: [String: DailyRecord] {
        Dictionary(records.map { ($0.dayKey, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("達成率と未使用時間")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                    Text("履歴")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 8)

                monthHeader
                    .padding(.top, 16)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    ForEach(cells) { cell in
                        if let date = cell.date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(height: 66)
                        }
                    }
                }
                .padding(.top, 6)

                detailCard
                    .padding(.top, 16)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .onAppear { today = TodayStatus.current() }
    }

    // MARK: - 月の切り替え

    private var monthHeader: some View {
        HStack {
            Button {
                month = calendar.date(byAdding: .month, value: -1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("前の月")
            Spacer()
            Text(month, format: .dateTime.year().month())
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button {
                month = calendar.date(byAdding: .month, value: 1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("次の月")
            .disabled(isCurrentMonth)
        }
        .foregroundStyle(Theme.textSecondary)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - カレンダー

    private struct Cell: Identifiable {
        let id: Int
        let date: Date?
    }

    /// 日曜始まり（デザインどおり）
    private var weekdayHeaders: [String] { calendar.veryShortStandaloneWeekdaySymbols }

    private var cells: [Cell] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let leading = calendar.component(.weekday, from: month) - 1
        var result = (0..<leading).map { Cell(id: -1 - $0, date: nil) }
        for day in range {
            result.append(Cell(id: day, date: calendar.date(byAdding: .day, value: day - 1, to: month)))
        }
        return result
    }

    /// その日の達成率と未使用時間。記録がない日は nil。
    private func dayValue(_ date: Date) -> (rate: Double, unused: Int)? {
        if calendar.isDateInToday(date) {
            guard today.hasFocusTime else { return nil }
            return (today.summary.achievementRate(goalMinutes: today.goalMinutes), today.summary.unusedMinutes)
        }
        guard let record = recordsByKey[FocusSettings.dayKey(date)] else { return nil }
        return (record.achievementRate, record.unusedMinutes)
    }

    private func dayCell(_ date: Date) -> some View {
        let isFuture = date > Date()
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selected)
        let value = dayValue(date)

        return Button {
            selected = date
        } label: {
            VStack(spacing: 3) {
                Text(date, format: .dateTime.day())
                    .font(.caption2.weight(isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? Theme.accentBright : (isFuture ? Color(hex: 0x5C6370) : Theme.textTertiary))
                ZStack {
                    if !isFuture {
                        FlowerRing(progress: value?.rate ?? 0, lineWidth: 3)
                        Text(value.map { DurationFormat.hm($0.unused) } ?? DurationFormat.empty)
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(value == nil ? Theme.textTertiary : Theme.textPrimary)
                    }
                }
                .frame(width: 42, height: 42)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(isSelected ? Color(hex: 0x141B2B) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color(hex: 0x2A3B5E) : .clear))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    // MARK: - 選んだ日の詳細

    @ViewBuilder
    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(selected, format: .dateTime.month().day().weekday())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let goalText {
                    Text(goalText)
                        .font(.caption)
                        .foregroundStyle(Theme.accentBright)
                }
            }
            if let stats = selectedStats {
                HStack(spacing: 8) {
                    stat("未使用時間", DurationFormat.hm(stats.unused))
                    stat("最長連続未使用", DurationFormat.hm(stats.longest))
                    stat("使用回数", String(localized: "\(stats.count)回"))
                }
            } else {
                Text("この日の記録はありません")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
    }

    private var selectedStats: (unused: Int, longest: Int, count: Int, goal: Int)? {
        if calendar.isDateInToday(selected) {
            guard today.hasFocusTime else { return nil }
            let s = today.summary
            return (s.unusedMinutes, s.longestUnusedMinutes, s.useCount, today.goalMinutes)
        }
        guard let r = recordsByKey[FocusSettings.dayKey(selected)] else { return nil }
        return (r.unusedMinutes, r.longestUnusedMinutes, r.useCount, r.goalMinutes)
    }

    private var goalText: String? {
        guard let stats = selectedStats, stats.goal > 0 else { return nil }
        let goal = DurationFormat.hm(stats.goal)
        return stats.unused >= stats.goal
            ? String(localized: "目標 \(goal) 達成")
            : String(localized: "目標 \(goal) まで あと \(DurationFormat.hm(stats.goal - stats.unused))")
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Text(value)
                .font(.title3.weight(.light))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 未実装の画面の仮表示。
struct PlaceholderScreen: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Theme.background)
    }
}
