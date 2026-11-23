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

struct MilestoneTests {
    private func memo(_ day: String, streak: Int, best: Int) -> MilestoneMemo {
        MilestoneMemo(dayKey: day, streak: streak, bestUnusedMinutes: best)
    }

    @Test func 節目の日数() {
        #expect([3, 7, 14, 30, 60, 100, 200].allSatisfy(Milestones.isMilestone))
        #expect(![1, 2, 4, 8, 31, 150].contains(where: Milestones.isMilestone))
    }

    @Test func 前の集中日から連続がつながり節目で知らせる() {
        let result = Milestones.closeDay(
            memo: memo("2026-11-20", streak: 6, best: 500),
            dayKey: "2026-11-23", previousFocusDayKey: "2026-11-20",
            unusedMinutes: 400, goalMinutes: 360
        )
        #expect(result?.memo == memo("2026-11-23", streak: 7, best: 500))
        #expect(result?.milestoneStreak == 7)
        #expect(result?.newBestMinutes == nil)
    }

    @Test func 未達なら連続は0に戻る() {
        let result = Milestones.closeDay(
            memo: memo("2026-11-20", streak: 6, best: 500),
            dayKey: "2026-11-23", previousFocusDayKey: "2026-11-20",
            unusedMinutes: 300, goalMinutes: 360
        )
        #expect(result?.memo.streak == 0)
        #expect(result?.milestoneStreak == nil)
    }

    @Test func 間の日を締めていなければ1から数える() {
        let result = Milestones.closeDay(
            memo: memo("2026-11-18", streak: 6, best: 500),
            dayKey: "2026-11-23", previousFocusDayKey: "2026-11-20",
            unusedMinutes: 400, goalMinutes: 360
        )
        #expect(result?.memo.streak == 1)
    }

    @Test func 自己ベストの更新() {
        let result = Milestones.closeDay(
            memo: memo("2026-11-20", streak: 0, best: 400),
            dayKey: "2026-11-21", previousFocusDayKey: "2026-11-20",
            unusedMinutes: 410, goalMinutes: 480
        )
        #expect(result?.newBestMinutes == 410)
        #expect(result?.memo.bestUnusedMinutes == 410)
    }

    @Test func 使い始めの日は自己ベストと言わない() {
        let result = Milestones.closeDay(memo: nil, dayKey: "2026-11-21", previousFocusDayKey: nil, unusedMinutes: 300, goalMinutes: 360)
        #expect(result?.newBestMinutes == nil)
        #expect(result?.memo.bestUnusedMinutes == 300)
    }

    @Test func 同じ日を2回締めない() {
        let result = Milestones.closeDay(
            memo: memo("2026-11-21", streak: 2, best: 400),
            dayKey: "2026-11-21", previousFocusDayKey: "2026-11-20",
            unusedMinutes: 500, goalMinutes: 360
        )
        #expect(result == nil)
    }

    @Test func 記録から合わせ直す() {
        let fromRecords = Milestones.reconciled(memo: memo("2026-11-18", streak: 1, best: 450), lastRecordDayKey: "2026-11-20", streakThroughLastRecord: 4, bestFromRecords: 420)
        #expect(fromRecords == memo("2026-11-20", streak: 4, best: 450))
        // 今日をもう締めていれば連続はそのまま
        let closedToday = Milestones.reconciled(memo: memo("2026-11-21", streak: 5, best: 400), lastRecordDayKey: "2026-11-20", streakThroughLastRecord: 4, bestFromRecords: 420)
        #expect(closedToday == memo("2026-11-21", streak: 5, best: 420))
    }

    @Test func 通知の文面() {
        #expect(Milestones.text(milestoneStreak: 7, newBestMinutes: nil) == "7日連続で目標を達成しました")
        #expect(Milestones.text(milestoneStreak: nil, newBestMinutes: 340) == "これまでで一番長い未使用時間です（5:40）")
        #expect(Milestones.text(milestoneStreak: 3, newBestMinutes: 400) == "3日連続で目標を達成しました\nこれまでで一番長い未使用時間です（6:40）")
        #expect(Milestones.text(milestoneStreak: nil, newBestMinutes: nil) == nil)
    }
}

struct TodayStatusLabelTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// 2026-11-23（月）の指定時刻
    private func monday(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: hour, minute: minute))!
    }

    private func label(_ date: Date) -> String {
        TodayStatusLabel.make(settings: .default, now: date, calendar: calendar).text
    }

    @Test func 状態ごとの札() {
        #expect(label(monday(10)) == "集中タイム中 ・ 18:00まで")
        #expect(TodayStatusLabel.make(settings: .default, now: monday(10), calendar: calendar).isFocus)
        #expect(label(monday(12, 30)) == "フリータイム ・ 13:00まで")
        #expect(label(monday(8)) == "次の集中タイム ・ 9:00から")
        #expect(label(monday(19)) == "今日の集中タイムは終わりました")
    }
}
