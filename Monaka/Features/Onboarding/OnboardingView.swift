import FamilyControls
import SwiftUI
import UserNotifications

/// 初回セットアップ（S-01）：スクリーンタイムの許可 → 通知の許可 → 集中タイムと目標。
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var step = 1
    @State private var errorMessage: String?

    // 3/3 で選ぶ内容（初期値：平日 9:00〜18:00、フリータイム 12:00〜13:00、目標 6:00）
    @State private var pickedWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var focus = TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 18))
    @State private var hasFreeTime = true
    @State private var free = TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13))
    @State private var goalMinutes = 6 * 60
    @State private var model = SettingsModel()

    private var draftDay: DaySchedule {
        DaySchedule(focus: [focus], free: hasFreeTime ? [free] : [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progressBar
                .padding(.top, 24)
            Group {
                switch step {
                case 1: screenTimeStep
                case 2: notificationStep
                default: scheduleStep
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Theme.accentBright : Color(hex: 0x232836))
                    .frame(height: 3)
            }
        }
        .accessibilityLabel(Text("ステップ \(step)/3"))
    }

    // MARK: - 1/3 スクリーンタイム

    private var screenTimeStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityHidden(true)
                Text("MONAKA")
                    .font(.system(size: 30, weight: .light))
                    .tracking(5)
                Text("集中している最中を、記録する。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 64)

            VStack(alignment: .leading, spacing: 10) {
                Text("スクリーンタイムの利用を許可してください")
                    .font(.subheadline.weight(.medium))
                bullet("集中タイム中に、iPhoneを使った分数と時刻だけを記録します")
                bullet("どのアプリを使ったかは見ません")
                bullet("記録はこのiPhoneの中だけに保存され、外部に送られません")
            }
            .padding(18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .padding(.top, 40)

            Spacer()
            PrimaryButton(title: "スクリーンタイムの利用を許可") {
                Task {
                    do {
                        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        errorMessage = nil
                        step = 2
                    } catch {
                        errorMessage = String(localized: "許可しないと記録できません。あとから設定で変更できます。")
                    }
                }
            }
        }
    }

    // MARK: - 2/3 通知

    private var notificationStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("通知を許可してください")
                .font(.title2.weight(.semibold))
                .padding(.top, 48)
            Text("集中タイム中は、必要なときだけ静かにお知らせします。")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            PrimaryButton(title: "通知を許可") {
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    step = 3
                }
            }
            Button("あとで") { step = 3 }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - 3/3 集中タイムと目標

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("集中タイムと目標を決めましょう")
                .font(.title2.weight(.semibold))
                .padding(.top, 40)
            Text("選んだ曜日に同じ時間を設定します。曜日ごとの調整はあとから設定で。")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)

            Text("曜日")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 24)
            HStack(spacing: 6) {
                ForEach(WeekdayOrder.mondayFirst, id: \.self) { weekday in
                    let isOn = pickedWeekdays.contains(weekday)
                    Button {
                        if isOn { pickedWeekdays.remove(weekday) } else { pickedWeekdays.insert(weekday) }
                    } label: {
                        Text(WeekdayOrder.shortName(weekday))
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(isOn ? Theme.textPrimary : Theme.textTertiary)
                            .background(isOn ? Color(hex: 0x1B2B4C) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isOn ? Theme.accent : Color(hex: 0x262B36))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.top, 10)

            VStack(spacing: 0) {
                HStack {
                    Text("集中タイム")
                    Spacer()
                    TimeRangeRow(range: $focus)
                }
                .frame(minHeight: 56)
                Divider().overlay(Theme.border)
                Toggle("フリータイム", isOn: $hasFreeTime)
                    .frame(minHeight: 48)
                if hasFreeTime {
                    HStack {
                        Spacer()
                        TimeRangeRow(range: $free)
                    }
                    .padding(.bottom, 8)
                }
                Divider().overlay(Theme.border)
                GoalStepper(minutes: $goalMinutes)
                    .frame(minHeight: 56)
            }
            .padding(.horizontal, 16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
            .padding(.top, 20)

            Text(summaryText)
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 12)

            Spacer()
            PrimaryButton(title: "はじめる") { start() }
            Text("ロック画面を長押しして「カスタマイズ」から、MONAKAのウィジェットを追加できます。")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private var summaryText: String {
        let target = draftDay.targetMinutes
        guard target > 0 else { return String(localized: "集中タイムを設定してください。") }
        let percent = Int((Double(goalMinutes) / Double(target) * 100).rounded())
        return String(localized: "記録の対象は1日 \(DurationFormat.hm(target))。目標 \(DurationFormat.hm(goalMinutes)) は対象の\(percent)%です。")
    }

    private func start() {
        guard !pickedWeekdays.isEmpty else {
            errorMessage = String(localized: "曜日を1つ以上選んでください。")
            return
        }
        let day = draftDay
        let saved = model.update { settings in
            settings.days = [:]
            for weekday in pickedWeekdays { settings.days[weekday] = day }
            settings.goalMinutes = goalMinutes
        }
        if saved {
            errorMessage = nil
            onFinish()
        } else {
            errorMessage = model.errorMessage
        }
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("・").foregroundStyle(Theme.accentBright)
            Text(text)
        }
        .font(.footnote)
        .foregroundStyle(Theme.textSecondary)
    }
}

struct PrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .foregroundStyle(.white)
        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    OnboardingView {}
}
