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
