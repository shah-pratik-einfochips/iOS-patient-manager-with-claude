import SwiftUI
import SwiftData

// MARK: - PatientFormView

struct PatientFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let patient: Patient?
    @State private var vm: PatientFormViewModel
    @State private var saveError: String?

    init(patient: Patient?) {
        self.patient = patient
        _vm = State(initialValue: patient.map(PatientFormViewModel.init(patient:)) ?? PatientFormViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                if let saveError {
                    Section { Text(saveError).foregroundStyle(.red).accessibilityLabel("Error: \(saveError)") }
                }
                Section("Identity") {
                    field("Medical ID", text: $vm.medicalID, error: vm.medicalIDError, capitalization: .characters)
                    field("First name", text: $vm.firstName, error: vm.firstNameError, content: .givenName)
                    field("Last name", text: $vm.lastName, error: vm.lastNameError, content: .familyName)
                    DatePicker("Date of birth", selection: $vm.dateOfBirth, in: ...Date(), displayedComponents: .date)
                    errorText(vm.dobError)
                    Picker("Gender", selection: $vm.gender) { ForEach(Gender.allCases) { Text($0.title).tag($0) } }
                    field("Ethnicity", text: $vm.ethnicity, error: nil)
                }
                Section("Contact") {
                    field("Phone", text: $vm.phone, error: vm.phoneError, keyboard: .phonePad, content: .telephoneNumber)
                    field("Email", text: $vm.email, error: vm.emailError, keyboard: .emailAddress, content: .emailAddress)
                }
                Section("Medical") {
                    Picker("Blood type", selection: $vm.bloodType) { ForEach(BloodType.allCases) { Text($0.rawValue).tag($0) } }
                    field("Allergies", text: $vm.allergies, error: nil, axis: .vertical)
                    field("Medications", text: $vm.medications, error: nil, axis: .vertical)
                    field("Health conditions", text: $vm.conditions, error: nil, axis: .vertical)
                }
                Section("Examination") {
                    field("Purpose of examination", text: $vm.examPurpose, error: nil, axis: .vertical)
                    Picker("Type of examination", selection: $vm.examType) { ForEach(ExaminationType.allCases) { Text($0.rawValue).tag($0) } }
                    field("Performed by", text: $vm.performedBy, error: nil)
                    field("Referred by", text: $vm.referredBy, error: nil)
                }
                Section {
                    Toggle("Patient consents to storage and sharing of health data", isOn: $vm.consentGiven)
                        .accessibilityHint("Required before data can be uploaded to the FHIR server")
                } header: { Text("Privacy & Consent") } footer: {
                    Text("Consent may be withdrawn at any time. Without consent, data stays on this device only (HIPAA / GDPR).")
                }
            }
            .navigationTitle(patient == nil ? "New Patient" : "Edit Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    /// Validates and persists the form.
    /// Shows inline errors on first failed attempt instead of closing.
    /// Returns nothing.
    private func save() {
        vm.submitted = true
        guard vm.isValid else { return }
        if PatientStore.isDuplicateMedicalID(vm.medicalID, excluding: patient?.id, in: context) {
            saveError = "A patient with this medical ID already exists."
            return
        }
        saveError = nil
        let audit = AuditLogger(context: context)
        if let patient {
            vm.apply(to: patient)
            audit.record("patient.update", detail: patient.id.uuidString)
        } else {
            let p = vm.makePatient()
            context.insert(p)
            audit.record("patient.create", detail: p.id.uuidString)
        }
        try? context.save()
        dismiss()
    }

    @ViewBuilder private func errorText(_ e: String?) -> some View {
        if vm.submitted, let e { Text(e).font(.footnote).foregroundStyle(.red).accessibilityLabel("Error: \(e)") }
    }

    private func field(_ title: String, text: Binding<String>, error: String?, keyboard: UIKeyboardType = .default,
                       content: UITextContentType? = nil, capitalization: TextInputAutocapitalization = .words,
                       axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(title, text: text, axis: axis)
                .keyboardType(keyboard)
                .textContentType(content)
                .textInputAutocapitalization(capitalization)
            errorText(error)
        }
    }
}
