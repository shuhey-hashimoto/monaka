import SwiftUI

/// 設定画面（S-05）。いまは曜日ごとの設定を表示するだけ。
/// TODO: 曜日の編集画面、目標時間、記録しない日。保存したら MonitorScheduler.apply を呼ぶ。
struct SettingsView: View {
    @State private var settings = FocusSettings.load()
    @State private var errorMessage: String?

    /// Calendar の weekday（1 = 日曜）を月曜始まりで並べる。
    private let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        NavigationStack {
            List {
                Section("曜日ごとの集中タイム") {
                    ForEach(weekdayOrder, id: \.self) { weekday in
                        HStack(alignment: .firstTextBaseline) {
                            Text(Calendar.current.shortWeekdaySymbols[weekday - 1])
                                .frame(width: 32, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(focusText(weekday))
                                if let free = freeText(weekday) {
                                    Text(free)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                    }
                }
                Section("目標と記録") {
                    LabeledContent("1日の目標時間", value: DurationFormat.hm(settings.goalMinutes))
                }
                Section {
                    Button("監視を登録し直す") { reapply() }
                } footer: {
                    if let errorMessage { Text(errorMessage) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("設定")
        }
    }

    private func focusText(_ weekday: Int) -> String {
        guard let day = settings.days[weekday], !day.focus.isEmpty else { return String(localized: "なし") }
        return day.focus.map { "\($0.start.text)〜\($0.end.text)" }.joined(separator: "、")
    }

    private func freeText(_ weekday: Int) -> String? {
        guard let day = settings.days[weekday], !day.free.isEmpty else { return nil }
        let ranges = day.free.map { "\($0.start.text)〜\($0.end.text)" }.joined(separator: "、")
        return String(localized: "フリータイム \(ranges)")
    }

    private func reapply() {
        do {
            try MonitorScheduler.apply(settings)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
