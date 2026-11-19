import SwiftUI
import SwiftData

// MARK: - PatientDetailView

struct PatientDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var patient: Patient
    @State private var tab = Tab.profile
    @State private var editing = false
    @State private var syncing = false
    @State private var syncMessage: String?

    enum Tab: String, CaseIterable, Identifiable { case profile = "Profile", vitals = "Enter Vitals", dashboard = "Dashboard"; var id: String { rawValue } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) { ForEach(Tab.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).padding()
            switch tab {
            case .profile: profile
            case .vitals: VitalsEntryView(patient: patient) { tab = .dashboard }
            case .dashboard: DashboardView(patient: patient)
            }
        }
        .navigationTitle(patient.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { Task { await sync() } } label: {
                    if syncing { ProgressView() } else { Image(systemName: "arrow.triangle.2.circlepath") }
                }
                .disabled(syncing)
                .accessibilityLabel("Sync with FHIR server")
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) { PatientFormView(patient: patient) }
        .alert("Sync", isPresented: Binding(isPresent: $syncMessage)) {
            Button("OK", role: .cancel) {}
        } message: { Text(syncMessage ?? "") }
    }

    private var profile: some View {
        List {
            Section("Demographics") {
                row("Medical ID", patient.medicalID)
                row("Date of birth", patient.dateOfBirth.formatted(date: .abbreviated, time: .omitted))
                row("Gender", patient.gender.title)
                row("Ethnicity", patient.ethnicity)
                row("Phone", patient.phone)
                row("Email", patient.email)
            }
            Section("Medical") {
                row("Blood type", patient.bloodType.rawValue)
                row("Allergies", patient.allergies)
                row("Medications", patient.medications)
                row("Conditions", patient.conditions)
            }
            Section("Examination") {
                row("Purpose", patient.examPurpose)
                row("Type", patient.examType.rawValue)
                row("Performed by", patient.performedBy)
                row("Referred by", patient.referredBy)
            }
            Section("Consent") {
                row("Status", patient.consentGiven ? "Granted" : "Not granted")
                if let d = patient.consentDate { row("Date", d.formatted()) }
                row("FHIR ID", patient.fhirID ?? "Not uploaded")
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) { Text(value.isEmpty ? "—" : value).multilineTextAlignment(.trailing) }
            .accessibilityElement(children: .combine)
    }

    /// Pushes then pulls data for this patient.
    /// Shows a result or error message in an alert.
    /// Returns nothing.
    private func sync() async {
        syncing = true
        defer { syncing = false }
        let service = SyncService(client: FHIRClient(baseURL: AppEnvironment.current().fhirBaseURL), context: context)
        do {
            try await service.push(patient)
            try await service.pull(patient)
            syncMessage = "Sync complete."
        } catch {
            syncMessage = error.localizedDescription
        }
    }
}
