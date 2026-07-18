import Foundation
import Combine

/// 1回の計測セッションの記録。
struct DoseRecord: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var durationSeconds: Int
    var totalCounts: Int
    var avgCpm: Double
    var maxCpm: Double
    var avgMicroSievertPerHour: Double
}

/// 計測履歴と積算被曝量の永続化。UserDefaultsにJSONで保存。
final class DoseStore: ObservableObject {
    @Published private(set) var records: [DoseRecord] = []
    /// 累積の推定被曝量（µSv）。参考値。
    @Published private(set) var cumulativeMicroSievert: Double = 0

    private let recordsKey = "geigerlens.records"
    private let cumulativeKey = "geigerlens.cumulative"

    init() {
        load()
    }

    func add(_ record: DoseRecord) {
        records.insert(record, at: 0)
        // durationぶんの推定線量を積算: µSv/h × 時間(h)
        let hours = Double(record.durationSeconds) / 3600.0
        cumulativeMicroSievert += record.avgMicroSievertPerHour * hours
        if records.count > 200 { records = Array(records.prefix(200)) }
        save()
    }

    func clearAll() {
        records.removeAll()
        cumulativeMicroSievert = 0
        save()
    }

    /// スクリーンショット撮影用のデモ履歴。永続化しない。
    func loadDemoState() {
        let now = Date()
        records = [
            DoseRecord(date: now.addingTimeInterval(-1800), durationSeconds: 312,
                       totalCounts: 137, avgCpm: 42, maxCpm: 118, avgMicroSievertPerHour: 0.24),
            DoseRecord(date: now.addingTimeInterval(-90000), durationSeconds: 605,
                       totalCounts: 208, avgCpm: 21, maxCpm: 64, avgMicroSievertPerHour: 0.12),
            DoseRecord(date: now.addingTimeInterval(-180000), durationSeconds: 180,
                       totalCounts: 33, avgCpm: 11, maxCpm: 29, avgMicroSievertPerHour: 0.06),
        ]
        cumulativeMicroSievert = 0.83
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([DoseRecord].self, from: data) {
            records = decoded
        }
        cumulativeMicroSievert = d.double(forKey: cumulativeKey)
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(records) {
            d.set(data, forKey: recordsKey)
        }
        d.set(cumulativeMicroSievert, forKey: cumulativeKey)
    }
}
