import Charts
import SwiftData
import SwiftUI

/// 分析画面（S-04）：直近1週間・1ヶ月の平均と、前の期間との比較。
struct AnalysisView: View {
    enum Period: CaseIterable, Identifiable {
        case week, month
        var id: Self { self }
        var days: Int { self == .week ? 7 : 30 }
        var label: LocalizedStringKey { self == .week ? "週" : "月" }
    }

    /// グラフの1日分。集中タイムのない日は unused が nil。
    struct DayPoint: Identifiable {
        let date: Date
        let unused: Int?
        let longest: Int?
        let achieved: Bool?
        let isToday: Bool
        var id: Date { date }
    }

    @Query(sort: \DailyRecord.date) private var records: [DailyRecord]
    @State private var period: Period = .week
    @State private var today = TodayStatus.current()

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rangeText)
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                    Text("分析")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                Picker("期間", selection: $period) {
                    ForEach(Period.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)

                averageCard
                chartCard
                comparison
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .onAppear { today = TodayStatus.current() }
    }

    // MARK: - データ

    private var recordsByKey: [String: DailyRecord] {
        Dictionary(records.map { ($0.dayKey, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// 今日から数えて offset 期間前の、期間ぶんの日（古い順）。
    private func points(periodsAgo offset: Int) -> [DayPoint] {
        let todayStart = calendar.startOfDay(for: Date())
        let byKey = recordsByKey
        return (0..<period.days).reversed().compactMap { back -> DayPoint? in
            guard let date = calendar.date(byAdding: .day, value: -(back + offset * period.days), to: todayStart) else { return nil }
            if calendar.isDateInToday(date) {
                guard today.hasFocusTime else { return DayPoint(date: date, unused: nil, longest: nil, achieved: nil, isToday: true) }
                return DayPoint(date: date, unused: today.summary.unusedMinutes, longest: today.summary.longestUnusedMinutes,
                                achieved: today.achieved, isToday: true)
            }
            let r = byKey[FocusSettings.dayKey(date)]
            return DayPoint(date: date, unused: r?.unusedMinutes, longest: r?.longestUnusedMinutes, achieved: r?.achieved, isToday: false)
        }
    }

    /// 平均は記録が確定した日だけで出す（今日は途中なので含めない）。
    private func average(_ points: [DayPoint], _ value: (DayPoint) -> Int?) -> Int? {
        DailyStats.average(points.filter { !$0.isToday }.compactMap(value))
    }

    private var current: [DayPoint] { points(periodsAgo: 0) }
    private var previous: [DayPoint] { points(periodsAgo: 1) }

    private var rangeText: String {
        guard let first = current.first?.date, let last = current.last?.date else { return "" }
        let style = Date.FormatStyle.dateTime.month().day()
        return "\(first.formatted(style))〜\(last.formatted(style))"
    }

    // MARK: - 表示

    private var averageCard: some View {
        let now = average(current, \.unused)
        let before = average(previous, \.unused)
        return VStack(alignment: .leading, spacing: 4) {
            Text("平均未使用時間（1日あたり）")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(now.map { DurationFormat.hm($0) } ?? DurationFormat.empty)
                    .font(.system(size: 44, weight: .ultraLight))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                if let now, let before {
                    Text(period == .week
                         ? "先週より \(DailyStats.signedHM(now - before))"
                         : "先月より \(DailyStats.signedHM(now - before))")
                        .font(.footnote)
                        .foregroundStyle(Theme.accentBright)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
    }

    private var chartCard: some View {
        let goalHours = Double(FocusSettings.load().goalMinutes) / 60
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("日ごとの未使用時間")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("- - 目標 \(DurationFormat.hm(FocusSettings.load().goalMinutes))")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            Chart {
                ForEach(current) { point in
                    if let unused = point.unused {
                        BarMark(
                            x: .value("日", point.date, unit: .day),
                            y: .value("未使用時間", Double(unused) / 60)
                        )
                        .foregroundStyle(point.isToday ? Color(hex: 0x2A3F66) : Theme.accent)
                        .cornerRadius(4)
                    }
                }
                RuleMark(y: .value("目標", goalHours))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.textTertiary)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 2)) { value in
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text("\(Int(hours)):00").font(.caption2).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                if period == .week {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                } else {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
            }
            .frame(height: 180)
            .accessibilityLabel(Text("日ごとの未使用時間のグラフ"))
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
    }

    private var comparison: some View {
        let nowDone = current.filter { !$0.isToday && $0.achieved != nil }
        let beforeDone = previous.filter { $0.achieved != nil }
        let nowAchieved = nowDone.filter { $0.achieved == true }.count
        let beforeAchieved = beforeDone.filter { $0.achieved == true }.count
        let nowLongest = average(current, \.longest)
        let beforeLongest = average(previous, \.longest)

        return VStack(alignment: .leading, spacing: 4) {
            Text(period == .week ? "先週との比較" : "先月との比較")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textTertiary)
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    Text(period == .week ? "今週" : "今月")
                    Text(period == .week ? "先週" : "先月")
                    Text("差")
                }
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                Divider().overlay(Theme.border)
                GridRow {
                    Text("目標達成").gridColumnAlignment(.leading)
                    Text("\(nowAchieved)/\(nowDone.count)日")
                    Text("\(beforeAchieved)/\(beforeDone.count)日").foregroundStyle(Theme.textSecondary)
                    Text(signedDays(nowAchieved - beforeAchieved)).foregroundStyle(Theme.accentBright)
                }
                Divider().overlay(Theme.border)
                GridRow {
                    Text("最長連続未使用").gridColumnAlignment(.leading)
                    Text(nowLongest.map { DurationFormat.hm($0) } ?? DurationFormat.empty)
                    Text(beforeLongest.map { DurationFormat.hm($0) } ?? DurationFormat.empty).foregroundStyle(Theme.textSecondary)
                    Text(diffText(nowLongest, beforeLongest)).foregroundStyle(Theme.accentBright)
                }
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Theme.textPrimary)
        }
        .padding(.top, 4)
    }

    private func signedDays(_ diff: Int) -> String {
        diff == 0 ? "±0日" : (diff > 0 ? "+\(diff)日" : "\(diff)日")
    }

    private func diffText(_ now: Int?, _ before: Int?) -> String {
        guard let now, let before else { return DurationFormat.empty }
        return DailyStats.signedHM(now - before)
    }
}
