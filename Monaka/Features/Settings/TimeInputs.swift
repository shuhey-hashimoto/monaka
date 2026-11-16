import SwiftUI

extension Binding where Value == TimeOfDay {
    /// DatePicker で時刻を選ぶための変換（今日の日付に時刻を乗せる）。
    var asDate: Binding<Date> {
        Binding<Date>(
            get: {
                Calendar.current.startOfDay(for: Date())
                    .addingTimeInterval(TimeInterval(wrappedValue.minutes * 60))
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                wrappedValue = TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0)
            }
        )
    }
}

/// 「9:00 〜 18:00」の時刻の組。
struct TimeRangeRow: View {
    @Binding var range: TimeRange

    var body: some View {
        HStack(spacing: 8) {
            DatePicker("開始", selection: $range.start.asDate, displayedComponents: .hourAndMinute)
                .labelsHidden()
            Text("〜")
                .foregroundStyle(Theme.textTertiary)
            DatePicker("終了", selection: $range.end.asDate, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }
}

/// 1日の目標時間を15分刻みで選ぶ。
struct GoalStepper: View {
    @Binding var minutes: Int

    var body: some View {
        Stepper(value: $minutes, in: 15...(16 * 60), step: 15) {
            LabeledContent("1日の目標時間") {
                Text(DurationFormat.hm(minutes))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accentBright)
            }
        }
    }
}

/// 6:00〜24:00 の時間割の帯（集中タイム＝紺、フリータイム・対象外＝暗いグレー）。
struct DayTimelineBar: View {
    let day: DaySchedule
    private let startMinute = 6 * 60
    private let endMinute = 24 * 60

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let scale = geo.size.width / CGFloat(endMinute - startMinute)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x151922))
                    ForEach(day.targetRanges()) { range in
                        let s = max(range.start.minutes, startMinute)
                        let e = min(range.end.minutes, endMinute)
                        if e > s {
                            Rectangle()
                                .fill(Theme.accent)
                                .frame(width: CGFloat(e - s) * scale)
                                .offset(x: CGFloat(s - startMinute) * scale)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(height: 28)
            HStack {
                Text("6:00")
                Spacer()
                Text("12:00")
                Spacer()
                Text("18:00")
                Spacer()
                Text("24:00")
            }
            .font(.caption2)
            .foregroundStyle(Theme.textTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("記録の対象は \(DurationFormat.hm(day.targetMinutes))"))
    }
}

/// Calendar の weekday（1 = 日曜）を月曜始まりで並べたもの。
enum WeekdayOrder {
    static let mondayFirst = [2, 3, 4, 5, 6, 7, 1]

    static func shortName(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    static func fullName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }
}
