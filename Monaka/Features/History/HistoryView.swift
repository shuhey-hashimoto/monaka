import SwiftUI

/// 履歴画面（S-03）。
/// TODO: 日次記録（F-06）を SwiftData に保存したあと、月カレンダーに花形の達成率を並べる。
struct HistoryView: View {
    var body: some View {
        PlaceholderScreen(title: "履歴", message: "月カレンダーで達成率と未使用時間を振り返る画面（実装予定）")
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
