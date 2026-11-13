import Foundation
import SwiftData
import OSLog

// MARK: - AuditLogger

/// Records security-relevant actions to the local encrypted store.
/// Entries never contain clinical values, only identifiers and action names.
@MainActor
struct AuditLogger {
    let context: ModelContext
    private static let logger = Logger(subsystem: "com.einfochips.PatientHealth", category: "audit")

    /// Writes an audit entry.
    /// Also mirrors it to OSLog with private detail.
    /// Returns nothing.
    func record(_ action: String, detail: String = "") {
        context.insert(AuditLogEntry(action: action, detail: detail))
        try? context.save()
        Self.logger.info("\(action, privacy: .public): \(detail, privacy: .private)")
    }
}
