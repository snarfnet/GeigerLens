import SwiftUI

/// 情報・調整・免責。
struct InfoView: View {
    @ObservedObject var detector: RadiationDetector
    @State private var factor: Double = 0.0057

    var body: some View {
        NavigationStack {
            ZStack {
                Retro.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        card("換算係数の調整", icon: "slider.horizontal.3") {
                            Text("cpm から μSv/h への換算係数です。カメラ方式では厳密でないため、手持ちの線量計に合わせて調整できます。")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                            HStack {
                                Text(String(format: "%.4f", factor))
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Retro.lcd)
                                Spacer()
                                Text("既定 0.0057")
                                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                            }
                            Slider(value: $factor, in: 0.001...0.02)
                                .tint(Retro.lcd)
                                .onChange(of: factor) { _, v in detector.conversionFactor = v }
                        }

                        card("測定情報", icon: "info.circle") {
                            infoRow("背景ノイズ", String(format: "%.2f /秒", detector.noiseFloor))
                            infoRow("フレーム明るさ", String(format: "%.0f", detector.frameBrightness))
                        }

                        card("免責事項", icon: "exclamationmark.shield") {
                            Text("本アプリはスマートフォンのカメラを使った簡易的な実験ツールです。本物の放射線測定器ではなく、表示値の正確性は保証されません。健康・安全・防災に関する判断には決して使用しないでください。")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Text("GeigerLens / ガイガーレンズ  v1.0")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("情報")
            .onAppear { factor = detector.conversionFactor }
        }
    }

    private func card(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Retro.lcd)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.panel))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Retro.lcd)
        }
    }
}
