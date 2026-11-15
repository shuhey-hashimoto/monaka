import DeviceActivity
import Foundation

/// 設定内容から、スクリーンタイムの監視を OS に登録する（システム要件定義書 4.1 / F-04）。
///
/// 対象区間ごとに「累計 1分・2分・3分…使った」イベントをまとめて登録しておく。
/// 閾値を超えるたびに検知拡張が呼ばれるので、監視を張り直さずに
/// 使い始めの時刻と使った分数の両方が分かる。
enum MonitorScheduler {
    static func apply(_ settings: FocusSettings) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring()

        for weekday in 1...7 {
            guard let day = settings.days[weekday] else { continue }
            for (index, range) in day.targetRanges().enumerated()
            where range.durationMinutes >= FocusSettings.minimumIntervalMinutes {
                let schedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: range.start.hour, minute: range.start.minute, weekday: weekday),
                    intervalEnd: DateComponents(hour: range.end.hour, minute: range.end.minute, weekday: weekday),
                    repeats: true
                )

                var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
                let count = min(range.durationMinutes, MonitorNames.maxEventsPerInterval)
                for minutes in 1...count {
                    // アプリを指定しない＝端末全体の使用を数える
                    events[DeviceActivityEvent.Name(MonitorNames.usedEvent(minutes: minutes))] =
                        DeviceActivityEvent(threshold: DateComponents(minute: minutes))
                }

                try center.startMonitoring(
                    DeviceActivityName(MonitorNames.activity(weekday: weekday, index: index)),
                    during: schedule,
                    events: events
                )
            }
        }
    }
}
