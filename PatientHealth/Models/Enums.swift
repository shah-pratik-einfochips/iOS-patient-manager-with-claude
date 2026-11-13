import Foundation

// MARK: - Gender

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male, female, other, unknown
    var id: String { rawValue }

    /// Display title for the gender.
    /// Used by pickers and summaries.
    /// Returns a human-readable string.
    var title: String { rawValue.capitalized }
}

// MARK: - BloodType

enum BloodType: String, CaseIterable, Identifiable, Codable {
    case unknown = "Unknown"
    case aPos = "A+", aNeg = "A-", bPos = "B+", bNeg = "B-"
    case abPos = "AB+", abNeg = "AB-", oPos = "O+", oNeg = "O-"
    var id: String { rawValue }
}

// MARK: - ExaminationType

enum ExaminationType: String, CaseIterable, Identifiable, Codable {
    case routineCheckup = "Routine checkup"
    case emergency = "Emergency"
    case followUp = "Follow-up"
    case consultation = "Consultation"
    case diagnostic = "Diagnostic"
    case preventive = "Preventive"
    var id: String { rawValue }
}

// MARK: - VitalType

enum VitalType: String, CaseIterable, Identifiable {
    case systolic, diastolic, map, heartRate, height, weight
    case temperature, respiratoryRate, spo2, painLevel
    var id: String { rawValue }

    /// Display title for the vital.
    /// Spelled out for clear clinical labeling.
    /// Returns a human-readable string.
    var title: String {
        switch self {
        case .systolic: "Systolic BP"
        case .diastolic: "Diastolic BP"
        case .map: "Mean Arterial Pressure"
        case .heartRate: "Heart Rate"
        case .height: "Height"
        case .weight: "Weight"
        case .temperature: "Temperature"
        case .respiratoryRate: "Respiratory Rate"
        case .spo2: "SpO₂ (Oxygen Saturation)"
        case .painLevel: "Pain Level"
        }
    }

    /// Canonical storage unit.
    /// All values are persisted in metric/canonical units.
    /// Returns the unit label.
    var unit: String {
        switch self {
        case .systolic, .diastolic, .map: "mmHg"
        case .heartRate: "bpm"
        case .height: "cm"
        case .weight: "kg"
        case .temperature: "°C"
        case .respiratoryRate: "breaths/min"
        case .spo2: "%"
        case .painLevel: "/10"
        }
    }

    /// Hard limits accepted by validation.
    /// Values outside are rejected as likely data-entry errors.
    /// Returns a closed range in canonical units.
    var validRange: ClosedRange<Double> {
        switch self {
        case .systolic: 50...260
        case .diastolic: 30...160
        case .map: 30...200
        case .heartRate: 20...250
        case .height: 30...260
        case .weight: 1...500
        case .temperature: 30...45
        case .respiratoryRate: 4...70
        case .spo2: 50...100
        case .painLevel: 0...10
        }
    }

    /// Clinically normal adult range.
    /// Values outside are flagged as abnormal in the UI.
    /// Returns a closed range in canonical units, or nil when no range applies.
    var normalRange: ClosedRange<Double>? {
        switch self {
        case .systolic: 90...120
        case .diastolic: 60...80
        case .map: 70...100
        case .heartRate: 60...100
        case .temperature: 36.1...37.2
        case .respiratoryRate: 12...20
        case .spo2: 95...100
        case .painLevel: 0...3
        case .height, .weight: nil
        }
    }

    /// Vitals that can be charted over time.
    /// Excludes height since it rarely changes.
    /// Returns the chartable subset.
    static var chartable: [VitalType] { allCases.filter { $0 != .height } }
}
