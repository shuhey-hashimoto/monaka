import Foundation
import Testing
@testable import Monaka

struct DayScheduleTests {
    @Test func フリータイムを除いた対象区間になる() {
        let day = DaySchedule(
            focus: [TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 18))],
            free: [TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13))]
        )
        let ranges = day.targetRanges().map { "\($0.start.text)-\($0.end.text)" }
        #expect(ranges == ["9:00-12:00", "13:00-18:00"])
    }

    @Test func 集中タイムの外のフリータイムは影響しない() {
        let day = DaySchedule(
            focus: [TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 12))],
            free: [TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13))]
        )
        #expect(day.targetRanges().count == 1)
        #expect(day.targetRanges().first?.durationMinutes == 180)
    }
}

struct UsageCalculatorTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let day = Date(timeIntervalSince1970: 1_794_700_800) // 基準日

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.startOfDay(for: day).addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
    }

    private var interval: TargetInterval {
        TargetInterval(id: "monaka.w2.i0", range: DateInterval(start: at(9), end: at(12)))
    }

    @Test func 使わなかった日は全部が未使用時間() {
        let summary = UsageCalculator.summarize(intervals: [interval], events: [], now: at(12))
        #expect(summary.targetMinutes == 180)
        #expect(summary.unusedMinutes == 180)
        #expect(summary.useCount == 0)
        #expect(summary.longestUnusedMinutes == 180)
    }

    @Test func 検知の間隔で使用回数と最長連続未使用を数える() {
        let events = [
            UsageEvent(date: at(10, 0), intervalID: interval.id, cumulativeMinutes: 1),
            UsageEvent(date: at(10, 1), intervalID: interval.id, cumulativeMinutes: 2),
            UsageEvent(date: at(11, 0), intervalID: interval.id, cumulativeMinutes: 3),
        ]
        let summary = UsageCalculator.summarize(intervals: [interval], events: events, now: at(12))
        #expect(summary.usedMinutes == 3)
        #expect(summary.unusedMinutes == 177)
        #expect(summary.useCount == 2)
        #expect(summary.sessionStarts == [at(9, 59), at(10, 59)])
        #expect(summary.longestUnusedMinutes == 60) // 11:00〜12:00
    }

    @Test func 進行中の区間は現在時刻までを数える() {
        let summary = UsageCalculator.summarize(intervals: [interval], events: [], now: at(10, 30))
        #expect(summary.targetMinutes == 90)
    }

    @Test func 目標に届く時刻を区間をまたいで求める() {
        let afternoon = TargetInterval(id: "monaka.w2.i1", range: DateInterval(start: at(13), end: at(18)))
        let fire = UsageCalculator.dateReachingGoal(
            intervals: [interval, afternoon],
            unusedMinutes: 150,
            goalMinutes: 360,
            now: at(11)
        )
        // 残り210分：11:00〜12:00で60分、13:00から150分 → 15:30
        #expect(fire == at(15, 30))
    }

    @Test func 時間はhmm形式で表す() {
        #expect(DurationFormat.hm(135) == "2:15")
        #expect(DurationFormat.hm(47) == "0:47")
    }
}
