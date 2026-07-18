import SwiftUI

/// アナログ針メーター。0〜maxを240°の扇形で表示。cpm表示に使用。
struct MeterView: View {
    var value: Double
    var maxValue: Double = 200

    private let startAngle: Double = -120
    private let endAngle: Double = 120

    private var fraction: Double { min(max(value / maxValue, 0), 1) }
    private var needleAngle: Double { startAngle + (endAngle - startAngle) * fraction }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                dialFace(size: size)
                colorArc(size: size)
                ticks(size: size)
                needle(size: size)
                hub(size: size)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dialFace(size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Retro.dial, Retro.dialShadow],
                                 center: .center, startRadius: 0, endRadius: size * 0.55))
            .overlay(Circle().stroke(Retro.bezel, lineWidth: size * 0.045))
            .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
    }

    private func colorArc(size: CGFloat) -> some View {
        let r = size * 0.40
        return ZStack {
            arc(0.0, 0.3, Color(red: 0.35, green: 0.85, blue: 0.55), size, r)
            arc(0.3, 0.6, Color(red: 0.98, green: 0.82, blue: 0.30), size, r)
            arc(0.6, 1.0, Color(red: 0.95, green: 0.25, blue: 0.20), size, r)
        }
    }

    private func arc(_ from: Double, _ to: Double, _ color: Color, _ size: CGFloat, _ radius: CGFloat) -> some View {
        let a0 = startAngle + (endAngle - startAngle) * from
        let a1 = startAngle + (endAngle - startAngle) * to
        return Path { p in
            p.addArc(center: CGPoint(x: size/2, y: size/2), radius: radius,
                     startAngle: .degrees(a0 - 90), endAngle: .degrees(a1 - 90), clockwise: false)
        }
        .stroke(color, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .butt))
    }

    private func ticks(size: CGFloat) -> some View {
        let count = 10
        return ZStack {
            ForEach(0...count, id: \.self) { i in
                let f = Double(i) / Double(count)
                let angle = startAngle + (endAngle - startAngle) * f
                Rectangle()
                    .fill(Retro.ink)
                    .frame(width: i % 5 == 0 ? 3 : 1.5,
                           height: i % 5 == 0 ? size * 0.06 : size * 0.035)
                    .offset(y: -size * 0.42)
                    .rotationEffect(.degrees(angle))
            }
        }
    }

    private func needle(size: CGFloat) -> some View {
        Rectangle()
            .fill(Retro.needle)
            .frame(width: size * 0.012, height: size * 0.44)
            .offset(y: -size * 0.18)
            .rotationEffect(.degrees(needleAngle))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: needleAngle)
    }

    private func hub(size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Retro.bezel, .black],
                                 center: .center, startRadius: 0, endRadius: size * 0.05))
            .frame(width: size * 0.10, height: size * 0.10)
    }
}
