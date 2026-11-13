import Foundation
import SwiftData

// MARK: - SyncService

/// Pushes local patients/vitals to the FHIR server and pulls remote vitals history.
@MainActor
final class SyncService {
    private let client: FHIRServicing
    private let context: ModelContext
    private let audit: AuditLogger

    init(client: FHIRServicing, context: ModelContext) {
        self.client = client
        self.context = context
        self.audit = AuditLogger(context: context)
    }

    /// Pushes a patient and any unsynced vitals.
    /// Requires consent; creates the Patient first so Observations can reference it.
    /// Throws on network or server failure.
    func push(_ patient: Patient) async throws {
        guard patient.consentGiven else { throw SyncError.consentRequired }
        let stored = try await client.upsertPatient(FHIRMapper.patientResource(patient))
        guard let pid = stored["id"] as? String else { throw FHIRError.decoding }
        patient.fhirID = pid

        for record in patient.vitals where record.fhirIDs.isEmpty {
            var ids: [String] = []
            for obs in FHIRMapper.observations(for: record, patientFHIRID: pid) {
                ids.append(try await client.createObservation(obs))
            }
            record.fhirIDs = ids
        }
        try context.save()
        audit.record("sync.push", detail: "patient=\(patient.id.uuidString)")
    }

    /// Pushes every consented patient; used by background sync.
    /// A failure for one patient does not stop the others.
    /// Returns the number of patients that failed.
    func pushAllConsented() async -> Int {
        let patients = (try? context.fetch(FetchDescriptor<Patient>(predicate: #Predicate { $0.consentGiven }))) ?? []
        var failures = 0
        for p in patients {
            if Task.isCancelled { failures += 1; break }
            do { try await push(p) } catch { failures += 1 }
        }
        return failures
    }

    /// Pulls patient demographics and vitals history.
    /// Remote observations are grouped by timestamp; timestamps already stored locally are skipped.
    /// Throws on network or server failure.
    func pull(_ patient: Patient) async throws {
        guard let pid = patient.fhirID else { throw SyncError.notSynced }
        FHIRMapper.apply(patientJSON: try await client.fetchPatient(id: pid), to: patient)

        let remote = try await client.fetchObservations(patientID: pid)
        let grouped = Dictionary(grouping: remote) { $0["effectiveDateTime"] as? String ?? "" }
        for (stamp, group) in grouped {
            guard let date = FHIRMapper.isoFormatter.date(from: stamp) else { continue }
            let known = patient.vitals.contains { abs($0.recordedAt.timeIntervalSince(date)) < 1 }
            guard !known, let record = FHIRMapper.vitalRecord(from: group, recordedAt: date) else { continue }
            record.fhirIDs = group.compactMap { $0["id"] as? String }
            record.patient = patient
            context.insert(record)
        }
        try context.save()
        audit.record("sync.pull", detail: "patient=\(patient.id.uuidString)")
    }

    enum SyncError: LocalizedError {
        case consentRequired, notSynced
        var errorDescription: String? {
            switch self {
            case .consentRequired: "Patient consent is required before data can be uploaded."
            case .notSynced: "This patient has not been uploaded yet."
            }
        }
    }
}
