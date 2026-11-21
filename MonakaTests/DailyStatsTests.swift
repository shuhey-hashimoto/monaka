import Foundation
import Testing
@testable import Monaka

struct DailyStatsTests {
    @Test func 連続達成は未達の日で途切れる() {
        #expect(DailyStats.streak(achievedNewestFirst: [true, true, false, true]) == 2)
        #expect(DailyStats.streak(achievedNewestFirst: []) == 0)
    }

    @Test func 今日が未達でも連続は途切れない() {
        #expect(DailyStats.streak(todayAchieved: false, pastAchievedNewestFirst: [true, true]) == 2)
        #expect(DailyStats.streak(todayAchieved: true, pastAchievedNewestFirst: [true, true]) == 3)
    }

    @Test func 差は符号つきのhmm() {
        #expect(DailyStats.signedHM(71) == "+1:11")
        #expect(DailyStats.signedHM(-20) == "-0:20")
        #expect(DailyStats.signedHM(0) == "±0:00")
    }

    @Test func 平均は四捨五入() {
        #expect(DailyStats.average([375, 391, 365, 368]) == 375)
        #expect(DailyStats.average([]) == nil)
    }
}

struct NotificationTextTests {
    private let workday = DaySchedule(
        focus: [TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 18))],
        free: [TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13))]
    )

    @Test func 区切りは開始とフリータイムの前後() {
        let boundaries = NotificationPlanner.boundaries(for: workday)
        #expect(boundaries.map(\.minute) == [9 * 60, 12 * 60, 13 * 60])
        #expect(boundaries.first?.body == "集中タイムを開始しました（18:00まで）")
        #expect(boundaries[1].body == "フリータイムです（13:00まで）")
        #expect(boundaries[2].body == "集中タイムを再開します（18:00まで）")
    }

    private func summary(unused: Int) -> DailySummary {
        DailySummary(targetMinutes: 480, usedMinutes: 480 - unused, longestUnusedMinutes: 0, sessionStarts: [])
    }

    @Test func 目標達成のサマリー() {
        let text = NotificationPlanner.summaryText(summary: summary(unused: 422), goalMinutes: 360, previousUnusedMinutes: nil)
        #expect(text == "今日は 7:02 使わずに過ごせました（達成率 100%）")
    }

    @Test func 未達だが前日より伸びたサマリー() {
        let text = NotificationPlanner.summaryText(summary: summary(unused: 300), goalMinutes: 360, previousUnusedMinutes: 240)
        #expect(text == "今日は 5:00。昨日より 1:00 長く集中できました")
    }

    @Test func 未達で前日より短いサマリー() {
        let text = NotificationPlanner.summaryText(summary: summary(unused: 200), goalMinutes: 360, previousUnusedMinutes: 240)
        #expect(text == "今日は 3:20。明日また挑戦しましょう")
    }
}
