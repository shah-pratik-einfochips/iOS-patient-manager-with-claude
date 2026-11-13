import Foundation
import SwiftData

// MARK: - PatientStore

enum PatientStore {

    /// Checks whether another patient already uses a medical ID.
    /// Comparison is exact after trimming whitespace; the patient being edited is excluded.
    /// Returns true when the ID is taken by a different patient.
    static func isDuplicateMedicalID(_ medicalID: String, excluding id: UUID?, in context: ModelContext) -> Bool {
        let trimmed = medicalID.trimmingCharacters(in: .whitespaces)
        let excluded = id ?? UUID()
        let descriptor = FetchDescriptor<Patient>(predicate: #Predicate { $0.medicalID == trimmed && $0.id != excluded })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }
}
