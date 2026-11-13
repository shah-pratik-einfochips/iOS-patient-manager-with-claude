import Foundation
import BackgroundTasks
import SwiftData

// MARK: - BackgroundSync

/// Periodically uploads consented patients while the app is in the background.
/// iOS decides when the task actually runs; it is best-effort, like WorkManager's periodic work.
enum BackgroundSync {
    static let taskID = "com.einfochips.PatientHealth.sync"
    static let interval: TimeInterval = 6 * 60 * 60

    /// Registers the refresh handler.
    /// Must be called before the app finishes launching.
    /// Returns nothing.
    static func register(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            schedule()
            let work = Task { @MainActor in
                let context = container.mainContext
                let service = SyncService(client: FHIRClient(baseURL: AppEnvironment.current().fhirBaseURL), context: context)
                let failures = await service.pushAllConsented()
                task.setTaskCompleted(success: failures == 0)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    /// Requests the next background refresh.
    /// Call whenever the app moves to the background.
    /// Returns nothing.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }
}
