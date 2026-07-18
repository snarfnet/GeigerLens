import SwiftUI

struct ContentView: View {
    @StateObject private var detector = RadiationDetector()
    @StateObject private var doseStore = DoseStore()
    private let click = ClickPlayer()
    @State private var selection = 0

    /// スクリーンショット撮影モード（起動引数 SCREENSHOT_MODE_N）。1=計測 2=履歴 3=使い方
    private static var screenshotMode: Int? {
        for arg in CommandLine.arguments {
            if arg.hasPrefix("SCREENSHOT_MODE_"), let n = Int(arg.dropFirst("SCREENSHOT_MODE_".count)) {
                return n
            }
        }
        return nil
    }

    var body: some View {
        TabView(selection: $selection) {
            GaugeScreen(detector: detector, doseStore: doseStore, click: click)
                .tabItem { Label("計測", systemImage: "dot.radiowaves.left.and.right") }
                .tag(0)

            HistoryView(doseStore: doseStore)
                .tabItem { Label("履歴", systemImage: "chart.xyaxis.line") }
                .tag(1)

            GuideView()
                .tabItem { Label("使い方", systemImage: "book") }
                .tag(2)

            InfoView(detector: detector)
                .tabItem { Label("情報", systemImage: "info.circle") }
                .tag(3)
        }
        .tint(Retro.lcd)
        .preferredColorScheme(.dark)
        .onAppear {
            guard let mode = Self.screenshotMode else { return }
            detector.loadDemoState()
            doseStore.loadDemoState()
            selection = min(max(mode - 1, 0), 2)
        }
        .onDisappear { detector.stop() }
    }
}
