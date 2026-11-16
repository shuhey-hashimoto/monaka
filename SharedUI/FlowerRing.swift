import SwiftUI

/// モナカの皮の形（10枚の花びら）。アイコン案Dと同じ形。
/// 上の中心から時計回りに描くので、trim で進み具合を表せる。
struct FlowerShape: Shape {
    var petals = 10
    /// 谷の半径 ÷ 花びらの先の半径
    var innerRatio: CGFloat = 0.908

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = 2 * CGFloat.pi / CGFloat(petals)

        func point(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }

        var path = Path()
        let first = -CGFloat.pi / 2
        path.move(to: point(inner, first))
        for i in 0..<petals {
            let a = first + CGFloat(i) * step
            path.addQuadCurve(to: point(inner, a + step), control: point(outer, a + step / 2))
        }
        path.closeSubpath()
        return path
    }
}

/// 花形の進み具合の表示（「今日」画面・履歴カレンダー）。
struct FlowerRing: View {
    var progress: Double
    var lineWidth: CGFloat
    var color: Color = Theme.accent

    var body: some View {
        ZStack {
            FlowerShape()
                .stroke(Theme.track, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
            FlowerShape()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .padding(lineWidth / 2)
    }
}

#Preview {
    FlowerRing(progress: 0.76, lineWidth: 12)
        .frame(width: 256, height: 256)
        .padding()
        .background(Theme.background)
}
