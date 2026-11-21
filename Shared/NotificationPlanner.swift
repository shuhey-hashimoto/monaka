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

    // MARK: - 区切り通知（F-09 / N-01〜N-03）

    static let boundaryPrefix = "monaka.boundary."

    /// その日の区切り：集中タイムの開始、フリータイムの開始、集中タイムの再開。
    struct Boundary: Equatable {
        var minute: Int
        var body: String
    }

    static func boundaries(for day: DaySchedule) -> [Boundary] {
        var result: [Boundary] = []
        let focus = day.focus.sorted { $0.start < $1.start }
        for f in focus {
            result.append(Boundary(
                minute: f.start.minutes,
                body: String(localized: "集中タイムを開始しました（\(f.end.text)まで）")
            ))
            for free in day.free where f.contains(minute: free.start.minutes) && free.start > f.start {
                let freeEnd = min(free.end, f.end)
                result.append(Boundary(
                    minute: free.start.minutes,
                    body: String(localized: "フリータイムです（\(freeEnd.text)まで）")
                ))
                if free.end < f.end {
                    result.append(Boundary(
                        minute: free.end.minutes,
                        body: String(localized: "集中タイムを再開します（\(f.end.text)まで）")
                    ))
                }
            }
        }
        return result.sorted { $0.minute < $1.minute }
    }

    /// 7日分の区切り通知を予約し直す。記録しない日は予約しない。
    /// 毎日繰り返しの通知にしないのは、記録しない日を飛ばすため。アプリを開くたびに予約し直す。
    static func scheduleBoundaries(settings: FocusSettings, from now: Date = Date(), days: Int = 7, calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix(boundaryPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)

            var added = 0
            let startOfToday = calendar.startOfDay(for: now)
            for offset in 0..<days {
                guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                      let schedule = settings.schedule(on: day, calendar: calendar) else { continue }
                for boundary in boundaries(for: schedule) {
                    let fire = day.addingTimeInterval(TimeInterval(boundary.minute * 60))
                    guard fire > now, added < 48 else { continue }
                    let content = UNMutableNotificationContent()
                    content.body = boundary.body
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let id = boundaryPrefix + FocusSettings.dayKey(day, calendar: calendar) + "." + String(boundary.minute)
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                    added += 1
                }
            }
        }
    }

    // MARK: - 終了時サマリー（F-11 / N-05〜N-07）

    static func summaryText(summary: DailySummary, goalMinutes: Int, previousUnusedMinutes: Int?) -> String {
        let unused = DurationFormat.hm(summary.unusedMinutes)
        if goalMinutes > 0, summary.unusedMinutes >= goalMinutes {
            let percent = Int((summary.achievementRate(goalMinutes: goalMinutes) * 100).rounded())
            return String(localized: "今日は \(unused) 使わずに過ごせました（達成率 \(percent)%）")
        }
        if let previous = previousUnusedMinutes, summary.unusedMinutes > previous {
            let diff = DurationFormat.hm(summary.unusedMinutes - previous)
            return String(localized: "今日は \(unused)。昨日より \(diff) 長く集中できました")
        }
        return String(localized: "今日は \(unused)。明日また挑戦しましょう")
    }

    static func sendSummary(_ text: String) {
        let content = UNMutableNotificationContent()
        content.body = text
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "monaka.summary", content: content, trigger: nil))
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
