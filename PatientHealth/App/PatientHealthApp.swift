import SwiftUI
import SwiftData

// MARK: - PatientHealthApp

@main
struct PatientHealthApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let schema = Schema([Patient.self, VitalRecord.self, AuditLogEntry.self])
        let env = ProcessInfo.processInfo
        let inMemory = env.arguments.contains("-uiTestingInMemory") || env.environment["XCTestConfigurationFilePath"] != nil
        if !inMemory, let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        do {
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
            if !inMemory {
                Self.protectStore()
                BackgroundSync.register(container: container)
            }
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        #if DEBUG
        if env.arguments.contains("-seedDemoData") { DemoData.seed(into: container.mainContext) }
        #endif
    }

    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(container)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { BackgroundSync.schedule() }
            }
    }

    /// Protects the SwiftData store files.
    /// Applies complete file protection (encrypted while the device is locked) and
    /// excludes the files from iCloud/device backups so PHI never leaves the device that way.
    /// Returns nothing.
    private static func protectStore() {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for f in files where f.hasSuffix(".store") || f.contains(".store-") {
            var url = dir.appendingPathComponent(f)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
    }
}
