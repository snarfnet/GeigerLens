import SwiftUI

/// 計測履歴と積算被曝量。
struct HistoryView: View {
    @ObservedObject var doseStore: DoseStore
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Retro.bg.ignoresSafeArea()
                if doseStore.records.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            cumulativeCard
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                        Section("計測ログ") {
                            ForEach(doseStore.records) { rec in
                                row(rec)
                                    .listRowBackground(Retro.panel)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("履歴")
            .toolbar {
                if !doseStore.records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("消去", role: .destructive) { showClearConfirm = true }
                            .tint(Retro.needle)
                    }
                }
            }
            .confirmationDialog("すべての履歴と積算量を消去しますか？",
                                isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("消去する", role: .destructive) { doseStore.clearAll() }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var cumulativeCard: some View {
        VStack(spacing: 6) {
            Text("積算被曝量（推定・参考値）")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Retro.lcd.opacity(0.7))
            Text(String(format: "%.2f μSv", doseStore.cumulativeMicroSievert))
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .foregroundStyle(Retro.lcd)
                .shadow(color: Retro.lcd.opacity(0.5), radius: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func row(_ rec: DoseRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rec.date, format: .dateTime.month().day().hour().minute())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(rec.durationSeconds)秒")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 14) {
                stat("平均", String(format: "%.0f cpm", rec.avgCpm))
                stat("最大", String(format: "%.0f cpm", rec.maxCpm))
                stat("線量", String(format: "%.3f μSv/h", rec.avgMicroSievertPerHour))
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            Text(value).font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Retro.lcd)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 44))
                .foregroundStyle(Retro.lcd.opacity(0.4))
            Text("まだ計測記録がありません")
                .foregroundStyle(.white.opacity(0.6))
            Text("計測タブで5秒以上計測すると記録されます")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}
