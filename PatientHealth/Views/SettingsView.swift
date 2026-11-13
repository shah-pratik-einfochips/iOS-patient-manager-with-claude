import SwiftUI
import SwiftData

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppEnvironment.storageKey) private var envRaw = AppEnvironment.default.rawValue
    @Query(sort: \AuditLogEntry.timestamp, order: .reverse) private var logs: [AuditLogEntry]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Environment", selection: $envRaw) { ForEach(AppEnvironment.allCases) { Text($0.rawValue).tag($0.rawValue) } }
                    Text((AppEnvironment(rawValue: envRaw) ?? .default).fhirBaseURL.absoluteString).font(.footnote).foregroundStyle(.secondary)
                } header: { Text("FHIR Server") } footer: {
                    Text("Development uses a public test server. Never upload real patient data to it.")
                }
                Section("Audit Log (\(logs.count))") {
                    ForEach(logs.prefix(50)) { l in
                        VStack(alignment: .leading) {
                            Text(l.action).font(.subheadline.bold())
                            Text(l.timestamp.formatted()).font(.caption).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
