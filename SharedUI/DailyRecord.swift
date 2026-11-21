import Foundation
import SwiftData

/// 1日分の記録（システム要件定義書 6章）。昨日までの日を使用ログからまとめて保存する。
/// アプリ本体とウィジェットの両方から読むため、ストアは App Group に置く。
@Model
final class DailyRecord {
    /// yyyy-MM-dd
    @Attribute(.unique) var dayKey: String
    /// その日の 0:00
    var date: Date
    var targetMinutes: Int
    var usedMinutes: Int
    var longestUnusedMinutes: Int
    var sessionStarts: [Date]
    /// その日の目標時間（あとで目標を変えても、過去の達成判定は変わらない）
    var goalMinutes: Int

    init(dayKey: String, date: Date, summary: DailySummary, goalMinutes: Int) {
        self.dayKey = dayKey
        self.date = date
        self.targetMinutes = summary.targetMinutes
        self.usedMinutes = summary.usedMinutes
        self.longestUnusedMinutes = summary.longestUnusedMinutes
        self.sessionStarts = summary.sessionStarts
        self.goalMinutes = goalMinutes
    }

    var unusedMinutes: Int { max(targetMinutes - usedMinutes, 0) }
    var useCount: Int { sessionStarts.count }
    var achieved: Bool { goalMinutes > 0 && unusedMinutes >= goalMinutes }

    var achievementRate: Double {
        guard goalMinutes > 0 else { return 0 }
        return min(Double(unusedMinutes) / Double(goalMinutes), 1)
    }
}

enum DailyStore {
    static let container: ModelContainer = {
        let schema = Schema([DailyRecord.self])
        let config = ModelConfiguration(
            "Monaka",
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )
        if let container = try? ModelContainer(for: schema, configurations: config) {
            return container
        }
        // 共有領域が使えないときはメモリ上だけで動かす（記録は残らない）
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: memory)
    }()

    static func records(in context: ModelContext) -> [DailyRecord] {
        (try? context.fetch(FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.date)]))) ?? []
    }
}
