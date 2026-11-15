import FamilyControls
import SwiftUI
import UserNotifications

/// 初回セットアップ（S-01）：スクリーンタイムの許可 → 通知の許可 → 集中タイムと目標。
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var step = 1
    @State private var errorMessage: String?

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
        VStack(alignment: .leading, spacing: 10) {
            Text("集中タイムと目標を決めましょう")
                .font(.title2.weight(.semibold))
                .padding(.top, 48)
            Text("平日 9:00〜18:00（フリータイム 12:00〜13:00）、目標 6:00 で始めます。曜日ごとの調整はあとから設定で。")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            // TODO: デザイン案どおり、曜日・時刻・目標をこの画面で選べるようにする
            Spacer()
            PrimaryButton(title: "はじめる") {
                let settings = FocusSettings.default
                settings.save()
                do {
                    try MonitorScheduler.apply(settings)
                    onFinish()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
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
