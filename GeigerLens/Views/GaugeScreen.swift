import SwiftUI

/// メイン計測画面。アナログメーター＋LCD数値＋遮光警告＋操作ボタン。
struct GaugeScreen: View {
    @ObservedObject var detector: RadiationDetector
    @ObservedObject var doseStore: DoseStore
    let click: ClickPlayer

    @State private var sessionStart: Date?
    @State private var maxCpm: Double = 0
    @State private var cpmSamples: [Double] = []
    @State private var usvSamples: [Double] = []
    @State private var soundOn = true

    private var isCovered: Bool { detector.frameBrightness < 20 }

    var body: some View {
        ZStack {
            Retro.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                meterPanel
                lcdPanel
                warningBar
                Spacer(minLength: 0)
                controls
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .onAppear {
            detector.onEvent = { if soundOn { click.click() } }
            click.soundEnabled = soundOn
        }
        .onChange(of: detector.cpm) { _, new in
            guard detector.isRunning else { return }
            if new > maxCpm { maxCpm = new }
            cpmSamples.append(new)
            usvSamples.append(detector.microSievertPerHour)
        }
    }

    private var header: some View {
        HStack {
            Text("GEIGER LENS")
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundStyle(Retro.lcd)
                .tracking(3)
            Spacer()
            Circle()
                .fill(detector.isRunning ? Retro.lcd : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)
                .shadow(color: detector.isRunning ? Retro.lcd : .clear, radius: 5)
        }
    }

    private var meterPanel: some View {
        MeterView(value: detector.cpm, maxValue: 200)
            .frame(height: 240)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Retro.panel)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Retro.bezel, lineWidth: 3))
            )
    }

    private var lcdPanel: some View {
        HStack(spacing: 12) {
            lcdBox(title: "CPM", value: String(format: "%.0f", detector.cpm))
            lcdBox(title: "μSv/h", value: String(format: "%.3f", detector.microSievertPerHour))
            lcdBox(title: "COUNT", value: "\(detector.totalCounts)")
        }
    }

    private func lcdBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Retro.lcd.opacity(0.7))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(Retro.lcd)
                .shadow(color: Retro.lcd.opacity(0.6), radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Retro.lcdDim, lineWidth: 1))
        )
    }

    @ViewBuilder
    private var warningBar: some View {
        if detector.permissionDenied {
            banner("カメラ権限がありません。設定アプリで許可してください。", color: Retro.needle)
        } else if detector.isRunning && !isCovered {
            banner("レンズを指や黒テープで完全に遮光してください（明るすぎます）", color: Retro.amber)
        } else if detector.isCalibrating {
            banner("キャリブレーション中… 背景ノイズを測定しています", color: Retro.lcd)
        } else if detector.isRunning && isCovered {
            banner("遮光OK。放射線を待機中…", color: Retro.lcd)
        }
    }

    private func banner(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: toggleRun) {
                    Label(detector.isRunning ? "停止" : "計測開始",
                          systemImage: detector.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(detector.isRunning ? Retro.needle : Retro.lcd)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    detector.calibrate()
                } label: {
                    Label("較正", systemImage: "scope")
                        .font(.system(size: 16, weight: .bold))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .background(Retro.panel)
                        .foregroundStyle(Retro.lcd)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!detector.isRunning)
            }
            Toggle(isOn: $soundOn) {
                Label("クリック音", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .tint(Retro.lcd)
            .onChange(of: soundOn) { _, v in click.soundEnabled = v }
        }
        .padding(.bottom, 8)
    }

    private func toggleRun() {
        if detector.isRunning {
            saveSession()
            detector.stop()
        } else {
            resetSession()
            detector.resetSession()
            detector.start()
            sessionStart = Date()
        }
    }

    private func resetSession() {
        maxCpm = 0
        cpmSamples.removeAll()
        usvSamples.removeAll()
    }

    private func saveSession() {
        guard let start = sessionStart else { return }
        let dur = Int(Date().timeIntervalSince(start))
        guard dur >= 5 else { return }
        let avgCpm = cpmSamples.isEmpty ? 0 : cpmSamples.reduce(0, +) / Double(cpmSamples.count)
        let avgUsv = usvSamples.isEmpty ? 0 : usvSamples.reduce(0, +) / Double(usvSamples.count)
        let rec = DoseRecord(date: start, durationSeconds: dur,
                             totalCounts: detector.totalCounts,
                             avgCpm: avgCpm, maxCpm: maxCpm,
                             avgMicroSievertPerHour: avgUsv)
        doseStore.add(rec)
        sessionStart = nil
    }
}
