import Foundation
import SwiftData
@testable import PatientHealth

/// Shared test fixtures, so a schema or initializer change touches one place.
enum TestSupport {
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: Schema.patientHealth, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    static func patient(_ medicalID: String = "M1", first: String = "A", last: String = "B", consent: Bool = false) -> Patient {
        Patient(medicalID: medicalID, firstName: first, lastName: last, dateOfBirth: Date(timeIntervalSince1970: 0), consentGiven: consent)
    }
}
