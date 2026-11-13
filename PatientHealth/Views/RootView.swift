import SwiftUI
import SwiftData

// MARK: - RootView

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Patient.lastName) private var patients: [Patient]
    @State private var selection: Patient?
    @State private var showingForm = false
    @State private var showingSettings = false
    @State private var search = ""

    private var filtered: [Patient] {
        search.isEmpty ? patients : patients.filter { $0.fullName.localizedCaseInsensitiveContains(search) || $0.medicalID.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(filtered) { p in
                    NavigationLink(value: p) {
                        VStack(alignment: .leading) {
                            Text(p.fullName).font(.headline)
                            Text("ID \(p.medicalID)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens patient details")
                }
                .onDelete(perform: delete)
            }
            .overlay { if patients.isEmpty { ContentUnavailableView("No Patients", systemImage: "person.crop.circle.badge.plus", description: Text("Tap + to register a patient.")) } }
            .searchable(text: $search, prompt: "Search name or medical ID")
            .navigationTitle("Patients")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingForm = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add patient")
                }
            }
        } detail: {
            if let selection {
                PatientDetailView(patient: selection)
            } else {
                ContentUnavailableView("Select a Patient", systemImage: "person.text.rectangle")
            }
        }
        .sheet(isPresented: $showingForm) { PatientFormView(patient: nil) }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    /// Deletes patients at the given offsets.
    /// Cascades to their vitals and logs the action.
    /// Returns nothing.
    private func delete(at offsets: IndexSet) {
        let audit = AuditLogger(context: context)
        for i in offsets {
            let p = filtered[i]
            audit.record("patient.delete", detail: p.id.uuidString)
            if selection == p { selection = nil }
            context.delete(p)
        }
        try? context.save()
    }
}
