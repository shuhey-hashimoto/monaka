import Foundation
import UserNotifications

/// 端末内で予約するローカル通知（サーバーからのプッシュ通知は使わない）。
enum NotificationPlanner {
    static let resetID = "monaka.reset"
    static let goalID = "monaka.goal"

    /// 連続未使用6時間でのリセット通知（BR-36 / N-08）。使用を検知するたびに組み替える。
    static func scheduleReset(lastUse: Date, intervalEnd: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [resetID])
        let fire = lastUse.addingTimeInterval(6 * 60 * 60)
        if let intervalEnd, fire >= intervalEnd { return }
        let seconds = fire.timeIntervalSinceNow
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        content.body = String(localized: "リセットの時間です。集中しすぎも毒なので気分転換をしましょう。")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: resetID, content: content, trigger: trigger))
    }

    static func cancelReset() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [resetID])
    }

    /// 目標達成の通知（BR-21 / N-04）。このまま使わなければ届く時刻に予約し、使用を検知したら後ろへずらす。
    static func scheduleGoal(at fireDate: Date?, goalMinutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [goalID])
        guard let fireDate else { return }
        let seconds = fireDate.timeIntervalSinceNow
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        content.body = String(localized: "今日の目標 \(DurationFormat.hm(goalMinutes)) を達成しました")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: goalID, content: content, trigger: trigger))
    }
}
