import SwiftData
import SwiftUI

enum RootTab: Hashable {
    case today, history, analysis, settings
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: RootTab = .today

    var body: some View {
        TabView(selection: $tab) {
            Tab("今日", systemImage: "clock", value: RootTab.today) {
                TodayView(onShowHistory: { tab = .history })
            }
            Tab("履歴", systemImage: "calendar", value: RootTab.history) {
                HistoryView()
            }
            Tab("分析", systemImage: "chart.bar", value: RootTab.analysis) {
                AnalysisView()
            }
            Tab("設定", systemImage: "slider.horizontal.3", value: RootTab.settings) {
                SettingsView()
            }
        }
        .task { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    /// アプリを開くたびに、昨日までを日次記録にまとめ、区切り通知を7日分予約し直す。
    private func refresh() {
        DailyRecorder.finalize(context: context)
        reconcileMilestones()
        NotificationPlanner.scheduleBoundaries(settings: FocusSettings.load())
    }

    /// 節目・自己ベストの判定に使うメモを、日次記録から数えた値に合わせ直す。
    /// 検知拡張は記録を開けないので、ここで正しい連続日数と自己ベストを渡しておく。
    private func reconcileMilestones() {
        let records = DailyStore.records(in: context)
        guard let last = records.last else { return }
        let memo = Milestones.reconciled(
            memo: MilestoneMemoStore.load(),
            lastRecordDayKey: last.dayKey,
            streakThroughLastRecord: DailyStats.streak(achievedNewestFirst: records.reversed().map(\.achieved)),
            bestFromRecords: records.map(\.unusedMinutes).max() ?? 0
        )
        MilestoneMemoStore.save(memo)
    }
}
