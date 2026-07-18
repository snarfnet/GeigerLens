import SwiftUI

/// 使い方＋原理＋免責。
struct GuideView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Retro.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        section("使い方", icon: "list.number") {
                            step(1, "背面カメラのレンズを、指や黒いテープで完全に遮光します。光が入らないほど正確です。")
                            step(2, "「計測開始」を押します。暗所でカメラが放射線由来の輝点を数えます。")
                            step(3, "最初に「較正」を押すと、その場の背景ノイズを測って精度を上げられます。")
                            step(4, "しばらく待つと cpm（毎分カウント）と推定 μSv/h が表示されます。")
                        }

                        section("原理", icon: "sparkles") {
                            para("カメラのCMOSセンサーにガンマ線が当たると、一瞬だけ明るい点（ホットピクセル）が現れます。これを1コマずつ数えて「イベント」とし、cpmに換算します。")
                        }

                        section("精度を上げるコツ", icon: "wand.and.stars") {
                            bullet("レンズを完全に遮光する（黒テープ＋指が確実）")
                            bullet("端末を動かさず、温度が安定した場所で使う")
                            bullet("計測前に必ず「較正」する")
                            bullet("数分間の平均で見る（短時間は揺らぎが大きい）")
                        }

                        disclaimer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("使い方")
        }
    }

    private func section(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Retro.lcd)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.panel))
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Retro.lcd))
            Text(text).font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("・").foregroundStyle(Retro.lcd)
            Text(text).font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
        }
    }

    private func para(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("重要な注意", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Retro.amber)
            Text("このアプリは本物のガイガー＝ミュラー管ではありません。カメラで拾えるのはガンマ線のごく一部で、感度は低く、値は正確な線量計とは異なります。医療・防災・安全判断には使えません。参考・実験・エンタメ用途としてお使いください。")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Retro.amber.opacity(0.10)))
    }
}
