import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("今日", systemImage: "clock") {
                TodayView()
            }
            Tab("履歴", systemImage: "calendar") {
                HistoryView()
            }
            Tab("分析", systemImage: "chart.bar") {
                AnalysisView()
            }
            Tab("設定", systemImage: "slider.horizontal.3") {
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
        NotificationPlanner.scheduleBoundaries(settings: FocusSettings.load())
    }
}
