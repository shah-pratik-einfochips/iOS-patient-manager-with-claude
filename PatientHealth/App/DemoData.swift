#if DEBUG
import Foundation
import SwiftData

// MARK: - DemoData

/// Debug-only sample data, enabled with the `-seedDemoData` launch argument. Not compiled into Release.
enum DemoData {

    /// Inserts one patient with seven days of varied vitals, including abnormal ones.
    /// Does nothing when patients already exist.
    /// Returns nothing.
    static func seed(into context: ModelContext) {
        guard ((try? context.fetchCount(FetchDescriptor<Patient>())) ?? 0) == 0 else { return }
        let p = Patient(medicalID: "MRN-1001", firstName: "Ann", lastName: "Lee",
                        dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date())!, consentGiven: true, consentDate: Date())
        context.insert(p)
        let hr = [72.0, 85, 130, 95, 58, 76, 101], sys = [118.0, 124, 150, 132, 112, 119, 141], dia = [76.0, 80, 95, 84, 70, 77, 90]
        let temp = [36.6, 36.8, 38.4, 37.0, 36.4, 36.7, 37.6], spo2 = [98.0, 97, 92, 96, 99, 98, 94]
        for i in 0..<7 {
            let v = VitalRecord(recordedAt: Date().addingTimeInterval(-Double(i) * 86_400 - 60), systolic: sys[i], diastolic: dia[i],
                                heartRate: hr[i], temperatureC: temp[i], respiratoryRate: 14 + Double(i), spo2: spo2[i],
                                painLevel: Double(i % 5), symptoms: i == 2 ? "fever, chills \"mild\"" : "")
            v.patient = p
            context.insert(v)
        }
        try? context.save()
    }
}
#endif
