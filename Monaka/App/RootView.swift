import SwiftUI

struct RootView: View {
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
    }
}
