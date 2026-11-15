import SwiftUI

@main
struct MonakaApp: App {
    @AppStorage("monaka.didOnboard") private var didOnboard = false

    var body: some Scene {
        WindowGroup {
            Group {
                if didOnboard {
                    RootView()
                } else {
                    OnboardingView { didOnboard = true }
                }
            }
            // ライト・ダークどちらの設定でも同じ「静寂」の雰囲気にする
            .preferredColorScheme(.dark)
            .tint(Theme.accentBright)
        }
    }
}
