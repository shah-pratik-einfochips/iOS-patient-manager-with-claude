import Foundation
import Observation

// MARK: - PatientFormViewModel

@Observable
final class PatientFormViewModel {
    var medicalID = ""
    var firstName = ""
    var lastName = ""
    var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    var gender: Gender = .unknown
    var ethnicity = ""
    var phone = ""
    var email = ""
    var bloodType: BloodType = .unknown
    var allergies = ""
    var medications = ""
    var conditions = ""
    var examPurpose = ""
    var examType: ExaminationType = .routineCheckup
    var performedBy = ""
    var referredBy = ""
    var consentGiven = false
    var submitted = false

    init() {}

    /// Creates a form prefilled from an existing patient.
    /// Used for editing.
    /// Returns a populated view model.
    init(patient p: Patient) {
        medicalID = p.medicalID; firstName = p.firstName; lastName = p.lastName
        dateOfBirth = p.dateOfBirth; gender = p.gender; ethnicity = p.ethnicity
        phone = p.phone; email = p.email; bloodType = p.bloodType
        allergies = p.allergies; medications = p.medications; conditions = p.conditions
        examPurpose = p.examPurpose; examType = p.examType
        performedBy = p.performedBy; referredBy = p.referredBy; consentGiven = p.consentGiven
    }

    var medicalIDError: String? { ValidationService.validateMedicalID(medicalID).message }
    var firstNameError: String? { ValidationService.validateName(firstName, field: "First name").message }
    var lastNameError: String? { ValidationService.validateName(lastName, field: "Last name").message }
    var dobError: String? { ValidationService.validateDateOfBirth(dateOfBirth).message }
    var phoneError: String? { ValidationService.validatePhone(phone).message }
    var emailError: String? { ValidationService.validateEmail(email).message }

    /// Whether every field passes validation.
    /// Gates the Save button.
    /// Returns true when the form can be saved.
    var isValid: Bool {
        [medicalIDError, firstNameError, lastNameError, dobError, phoneError, emailError].allSatisfy { $0 == nil }
    }

    /// Copies form values onto a patient model.
    /// Records the consent timestamp when consent changes to granted.
    /// Returns nothing.
    func apply(to p: Patient) {
        p.medicalID = medicalID.trimmingCharacters(in: .whitespaces)
        p.firstName = firstName.trimmingCharacters(in: .whitespaces)
        p.lastName = lastName.trimmingCharacters(in: .whitespaces)
        p.dateOfBirth = dateOfBirth; p.gender = gender; p.ethnicity = ethnicity
        p.phone = phone; p.email = email; p.bloodType = bloodType
        p.allergies = allergies; p.medications = medications; p.conditions = conditions
        p.examPurpose = examPurpose; p.examType = examType
        p.performedBy = performedBy; p.referredBy = referredBy
        p.setConsent(consentGiven)
        p.updatedAt = Date()
    }

    /// Builds a new patient from the form.
    /// Callers should check isValid first.
    /// Returns an unsaved Patient.
    func makePatient() -> Patient {
        let p = Patient(medicalID: medicalID, firstName: firstName, lastName: lastName, dateOfBirth: dateOfBirth)
        apply(to: p)
        return p
    }
}
