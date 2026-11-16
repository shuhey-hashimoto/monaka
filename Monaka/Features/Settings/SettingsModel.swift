import Foundation
import Observation
import WidgetKit

/// 設定の読み書き。保存すると、スクリーンタイムの監視を登録し直し、ウィジェットを更新する。
@Observable
final class SettingsModel {
    private(set) var settings: FocusSettings
    var errorMessage: String?

    init(settings: FocusSettings = .load()) {
        self.settings = settings
    }

    /// 設定を変えて保存する。入力チェックや監視の登録に失敗したら何も変えずに false を返す。
    /// 時間帯を変えないとき（目標時間・記録しない日）は reschedule: false で監視の登録し直しを省く。
    @discardableResult
    func update(reschedule: Bool = true, _ change: (inout FocusSettings) -> Void) -> Bool {
        var candidate = settings
        change(&candidate)

        if let problem = candidate.validationError {
            errorMessage = problem
            return false
        }
        if reschedule {
            do {
                try MonitorScheduler.apply(candidate)
            } catch {
                errorMessage = String(localized: "監視の登録に失敗しました：\(error.localizedDescription)")
                return false
            }
        }
        candidate.save()
        settings = candidate
        errorMessage = nil
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }
}
