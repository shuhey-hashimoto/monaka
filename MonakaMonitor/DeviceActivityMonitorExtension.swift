import DeviceActivity
import Foundation
import WidgetKit

/// 使用検知の拡張機能（システム要件定義書 4.2）。
/// アプリが閉じていても OS から呼ばれる。メモリ上限が数MBなので処理は最小限にする。
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let now = Date()
        // 記録しない日は何もしない
        guard !FocusSettings.load().isSkipped(now) else { return }
        let interval = currentInterval(for: activity, at: now)
        // 区間の始まりを起点に、6時間のリセット通知と目標達成通知を予約し直す
        NotificationPlanner.scheduleReset(lastUse: now, intervalEnd: interval?.range.end)
        rescheduleGoal(now: now)
        WidgetCenter.shared.reloadAllTimelines()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        NotificationPlanner.cancelReset()
        WidgetCenter.shared.reloadAllTimelines()
        // TODO: その日最後の区間なら終了時サマリー通知（F-11）を送る
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let minutes = MonitorNames.minutes(fromEvent: event.rawValue) else { return }

        let now = Date()
        guard !FocusSettings.load().isSkipped(now) else { return }
        let store = UsageLogStore()
        // 同じ閾値の重複は無視する（iOS 26系の誤検知対策）
        guard !store.contains(intervalID: activity.rawValue, cumulativeMinutes: minutes, on: now) else { return }

        store.append(UsageEvent(date: now, intervalID: activity.rawValue, cumulativeMinutes: minutes))
        store.lastUseDate = now

        let interval = currentInterval(for: activity, at: now)
        NotificationPlanner.scheduleReset(lastUse: now, intervalEnd: interval?.range.end)
        rescheduleGoal(now: now)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func currentInterval(for activity: DeviceActivityName, at date: Date) -> TargetInterval? {
        FocusSettings.load().intervals(on: date).first { $0.id == activity.rawValue }
    }

    private func rescheduleGoal(now: Date) {
        let settings = FocusSettings.load()
        let intervals = settings.intervals(on: now)
        let summary = UsageCalculator.summarize(intervals: intervals, events: UsageLogStore().events(on: now), now: now)
        let fire = UsageCalculator.dateReachingGoal(
            intervals: intervals,
            unusedMinutes: summary.unusedMinutes,
            goalMinutes: settings.goalMinutes,
            now: now
        )
        NotificationPlanner.scheduleGoal(at: fire, goalMinutes: settings.goalMinutes)
    }
}
