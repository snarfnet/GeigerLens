import SwiftUI

struct ContentView: View {
    @StateObject private var detector = RadiationDetector()
    @StateObject private var doseStore = DoseStore()
    private let click = ClickPlayer()

    var body: some View {
        TabView {
            GaugeScreen(detector: detector, doseStore: doseStore, click: click)
                .tabItem { Label("計測", systemImage: "dot.radiowaves.left.and.right") }

            HistoryView(doseStore: doseStore)
                .tabItem { Label("履歴", systemImage: "chart.xyaxis.line") }

            GuideView()
                .tabItem { Label("使い方", systemImage: "book") }

            InfoView(detector: detector)
                .tabItem { Label("情報", systemImage: "info.circle") }
        }
        .tint(Retro.lcd)
        .preferredColorScheme(.dark)
        .onDisappear { detector.stop() }
    }
}
