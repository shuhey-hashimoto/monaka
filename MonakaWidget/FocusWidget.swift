import SwiftUI
import WidgetKit

/// ロック画面ウィジェット（横長のみ）の表示状態（システム要件定義書 5.2 / 9.3）。
enum FocusWidgetState {
    /// W-01 集中タイム中：最後に使ってからの経過時間
    case focus(since: Date)
    /// W-02 フリータイム中
    case free(until: Date)
    /// W-03 対象外の時間（今日の集中タイムがまだある）
    case next(start: Date)
    /// W-04 今日の集中タイムがない・終わった
    case none
}

struct FocusEntry: TimelineEntry {
    let date: Date
    let state: FocusWidgetState
}

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: Date(), state: .focus(since: Date().addingTimeInterval(-47 * 60)))
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    /// 1日分の切り替わり（区間の開始・終了）を前もって並べる。
    /// 経過時間は Text(_:style:) が OS 側で数えるので、定期的な更新はしない。
    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        let now = Date()
        let intervals = FocusSettings.load().intervals(on: now)
        var dates = [now]
        for interval in intervals {
            dates.append(interval.range.start)
            dates.append(interval.range.end)
        }
        let entries = dates.filter { $0 >= now }.sorted().map { entry(at: $0) }
        let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60 + 60)
        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }

    private func entry(at date: Date) -> FocusEntry {
        let settings = FocusSettings.load()
        let intervals = settings.intervals(on: date)

        if let current = intervals.first(where: { $0.range.contains(date) && date < $0.range.end }) {
            let lastUse = UsageLogStore().lastUseDate ?? current.range.start
            return FocusEntry(date: date, state: .focus(since: max(lastUse, current.range.start)))
        }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let minute = Int(date.timeIntervalSince(startOfDay) / 60)
        if let free = settings.schedule(on: date)?.free.first(where: { $0.contains(minute: minute) }) {
            let until = startOfDay.addingTimeInterval(TimeInterval(free.end.minutes * 60))
            return FocusEntry(date: date, state: .free(until: until))
        }

        if let next = intervals.first(where: { $0.range.start > date }) {
            return FocusEntry(date: date, state: .next(start: next.range.start))
        }
        return FocusEntry(date: date, state: .none)
    }
}

struct FocusWidgetView: View {
    let entry: FocusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch entry.state {
            case .focus(let since):
                Text("現在")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                // TODO(PoC): 「0:47」の h:mm 表記にできるか確認する（.timer は 47:12 の形になる）
                Text(since, style: .timer)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("使用していません")
                    .font(.caption)
            case .free(let until):
                Text("フリータイム")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(until, style: .time)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("まで触ってOK")
                    .font(.caption)
            case .next(let start):
                Text("次の集中タイム")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(start, style: .time)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Text("から")
                    .font(.caption)
            case .none:
                Text("今日の集中タイムは\nありません")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct FocusWidget: Widget {
    let kind = "FocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusProvider()) { entry in
            FocusWidgetView(entry: entry)
        }
        .configurationDisplayName("集中タイム")
        .description("最後にiPhoneを使ってからの時間を表示します。")
        .supportedFamilies([.accessoryRectangular])
    }
}
