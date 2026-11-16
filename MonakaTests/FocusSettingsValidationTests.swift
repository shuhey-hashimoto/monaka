import Foundation
import Testing
@testable import Monaka

struct FocusSettingsValidationTests {
    private func settings(focus: TimeRange, free: [TimeRange] = [], goal: Int = 360) -> FocusSettings {
        FocusSettings(days: [2: DaySchedule(focus: [focus], free: free)], goalMinutes: goal)
    }

    @Test func 標準の設定は保存できる() {
        #expect(FocusSettings.default.validationError == nil)
    }

    @Test func 終了が開始より前なら保存できない() {
        let s = settings(focus: TimeRange(start: TimeOfDay(hour: 18), end: TimeOfDay(hour: 9)))
        #expect(s.validationError != nil)
    }

    @Test func フリータイムで15分未満の区間ができたら保存できない() {
        let s = settings(
            focus: TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 13)),
            free: [TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 12, minute: 50))]
        )
        // 12:50〜13:00 の10分が残る
        #expect(s.validationError != nil)
    }

    @Test func 目標時間が0なら保存できない() {
        let s = settings(focus: TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 18)), goal: 0)
        #expect(s.validationError != nil)
    }

    @Test func 追加する区間は最後の区間の終わりから1時間() {
        let next = DaySchedule.nextRange(after: [TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 18))])
        #expect(next.start == TimeOfDay(hour: 18))
        #expect(next.end == TimeOfDay(hour: 19))
    }

    @Test func 記録の対象時間はフリータイムを除いた合計() {
        let day = DaySchedule(
            focus: [TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 18))],
            free: [TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13))]
        )
        #expect(day.targetMinutes == 8 * 60)
    }
}
