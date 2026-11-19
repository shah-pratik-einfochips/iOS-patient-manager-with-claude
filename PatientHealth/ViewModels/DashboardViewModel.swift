import Foundation
import Observation

// MARK: - DashboardViewModel

@Observable
final class DashboardViewModel {
    var selectedType: VitalType = .heartRate
    var showChart = true

    struct Stats: Equatable { let min: Double; let max: Double; let average: Double; let latest: Double; let count: Int }
    /// Point identity is the source record, so chart marks keep their identity across redraws.
    struct Point: Identifiable { let id: UUID; let date: Date; let value: Double; let abnormal: Bool }

    /// Length of the dashboard window, in days.
    static let windowDays = 7

    /// Filters records to the past N days, oldest first.
    /// Defaults to seven days ending now.
    /// Returns the filtered, sorted records.
    func recent(_ records: [VitalRecord], days: Int = windowDays, now: Date = Date()) -> [VitalRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? .distantPast
        return records.filter { $0.recordedAt >= start && $0.recordedAt <= now }.sorted { $0.recordedAt < $1.recordedAt }
    }

    /// Builds chart points for one vital type.
    /// Skips records without that vital.
    /// Returns points with abnormal flags.
    func points(_ records: [VitalRecord], type: VitalType) -> [Point] {
        records.compactMap { r in
            r.value(for: type).map { Point(id: r.id, date: r.recordedAt, value: $0, abnormal: ValidationService.isAbnormal($0, type: type)) }
        }
    }

    /// Computes summary statistics.
    /// Latest is the most recent value by date.
    /// Returns nil when there are no values.
    func stats(_ records: [VitalRecord], type: VitalType) -> Stats? { stats(points(records, type: type)) }

    /// Summary statistics over points that are already computed.
    func stats(_ pts: [Point]) -> Stats? {
        guard let latest = pts.max(by: { $0.date < $1.date }) else { return nil }
        let values = pts.map(\.value)
        return Stats(min: values.min()!, max: values.max()!, average: (values.reduce(0, +) / Double(values.count)).rounded(toPlaces: 1),
                     latest: latest.value, count: values.count)
    }
}
