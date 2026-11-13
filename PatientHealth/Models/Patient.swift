import Foundation
import SwiftData

// MARK: - Patient

@Model
final class Patient {
    @Attribute(.unique) var id: UUID
    var medicalID: String
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var genderRaw: String
    var ethnicity: String
    var phone: String
    var email: String
    var bloodTypeRaw: String
    var allergies: String
    var medications: String
    var conditions: String

    var examPurpose: String
    var examTypeRaw: String
    var performedBy: String
    var referredBy: String

    var consentGiven: Bool
    var consentDate: Date?
    var fhirID: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \VitalRecord.patient)
    var vitals: [VitalRecord] = []

    init(medicalID: String, firstName: String, lastName: String, dateOfBirth: Date,
         gender: Gender = .unknown, ethnicity: String = "", phone: String = "", email: String = "",
         bloodType: BloodType = .unknown, allergies: String = "", medications: String = "",
         conditions: String = "", examPurpose: String = "", examType: ExaminationType = .routineCheckup,
         performedBy: String = "", referredBy: String = "",
         consentGiven: Bool = false, consentDate: Date? = nil) {
        self.id = UUID()
        self.medicalID = medicalID
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.genderRaw = gender.rawValue
        self.ethnicity = ethnicity
        self.phone = phone
        self.email = email
        self.bloodTypeRaw = bloodType.rawValue
        self.allergies = allergies
        self.medications = medications
        self.conditions = conditions
        self.examPurpose = examPurpose
        self.examTypeRaw = examType.rawValue
        self.performedBy = performedBy
        self.referredBy = referredBy
        self.consentGiven = consentGiven
        self.consentDate = consentDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .unknown }
        set { genderRaw = newValue.rawValue }
    }
    var bloodType: BloodType {
        get { BloodType(rawValue: bloodTypeRaw) ?? .unknown }
        set { bloodTypeRaw = newValue.rawValue }
    }
    var examType: ExaminationType {
        get { ExaminationType(rawValue: examTypeRaw) ?? .routineCheckup }
        set { examTypeRaw = newValue.rawValue }
    }
    var fullName: String { "\(firstName) \(lastName)" }
}

// MARK: - VitalRecord

@Model
final class VitalRecord {
    @Attribute(.unique) var id: UUID
    var recordedAt: Date
    var systolic: Double?
    var diastolic: Double?
    var heartRate: Double?
    var heightCm: Double?
    var weightKg: Double?
    var temperatureC: Double?
    var respiratoryRate: Double?
    var spo2: Double?
    var painLevel: Double?
    var symptoms: String
    var fhirIDs: [String] = []
    var patient: Patient?

    init(recordedAt: Date = Date(), systolic: Double? = nil, diastolic: Double? = nil,
         heartRate: Double? = nil, heightCm: Double? = nil, weightKg: Double? = nil,
         temperatureC: Double? = nil, respiratoryRate: Double? = nil, spo2: Double? = nil,
         painLevel: Double? = nil, symptoms: String = "") {
        self.id = UUID()
        self.recordedAt = recordedAt
        self.systolic = systolic
        self.diastolic = diastolic
        self.heartRate = heartRate
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.temperatureC = temperatureC
        self.respiratoryRate = respiratoryRate
        self.spo2 = spo2
        self.painLevel = painLevel
        self.symptoms = symptoms
    }

    /// Mean arterial pressure derived from systolic and diastolic.
    /// Computed rather than stored so it is always consistent.
    /// Returns nil when either pressure is missing.
    var map: Double? {
        guard let systolic, let diastolic else { return nil }
        return UnitConversion.meanArterialPressure(systolic: systolic, diastolic: diastolic)
    }

    /// Looks up the value for a vital type.
    /// Centralizes the type-to-property mapping for charts and export.
    /// Returns the canonical-unit value or nil if not recorded.
    func value(for type: VitalType) -> Double? {
        switch type {
        case .systolic: systolic
        case .diastolic: diastolic
        case .map: map
        case .heartRate: heartRate
        case .height: heightCm
        case .weight: weightKg
        case .temperature: temperatureC
        case .respiratoryRate: respiratoryRate
        case .spo2: spo2
        case .painLevel: painLevel
        }
    }
}

// MARK: - AuditLogEntry

@Model
final class AuditLogEntry {
    var id: UUID
    var timestamp: Date
    var action: String
    var detail: String

    init(action: String, detail: String = "") {
        self.id = UUID()
        self.timestamp = Date()
        self.action = action
        self.detail = detail
    }
}
