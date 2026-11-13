import XCTest
import SwiftData
@testable import PatientHealth

// MARK: - Mock transport

final class MockTransport: HTTPTransport {
    var responses: [Result<(Int, [String: Any]), Error>] = []
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let r = responses.isEmpty ? .success((200, [:])) : responses.removeFirst()
        switch r {
        case .failure(let e): throw e
        case .success(let (code, body)):
            let data = try JSONSerialization.data(withJSONObject: body)
            return (data, HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!)
        }
    }
}

final class FHIRMapperTests: XCTestCase {
    func patient() -> Patient {
        let p = Patient(medicalID: "MRN9", firstName: "Ann", lastName: "Lee",
                        dateOfBirth: FHIRMapper.dateFormatter.date(from: "1990-05-17")!,
                        gender: .female, phone: "5551234567", email: "a@b.co", bloodType: .oPos)
        return p
    }
    func testPatientResource() {
        let j = FHIRMapper.patientResource(patient())
        XCTAssertEqual(j["resourceType"] as? String, "Patient")
        XCTAssertEqual(j["gender"] as? String, "female")
        XCTAssertEqual(j["birthDate"] as? String, "1990-05-17")
        XCTAssertEqual((j["telecom"] as? [[String: Any]])?.count, 2)
        XCTAssertNil(j["id"])
        XCTAssertEqual(((j["name"] as? [[String: Any]])?.first)?["family"] as? String, "Lee")
    }
    func testPatientResourceOmitsEmptyTelecomAndIncludesID() {
        let p = patient(); p.phone = ""; p.email = ""; p.fhirID = "42"
        let j = FHIRMapper.patientResource(p)
        XCTAssertEqual((j["telecom"] as? [Any])?.count, 0)
        XCTAssertEqual(j["id"] as? String, "42")
    }
    func testApplyPatientJSON() {
        let p = patient()
        FHIRMapper.apply(patientJSON: ["id": "7", "name": [["family": "Kim", "given": ["Joy"]]], "gender": "male",
                                       "birthDate": "1980-01-02", "telecom": [["system": "phone", "value": "999"]]], to: p)
        XCTAssertEqual(p.fhirID, "7"); XCTAssertEqual(p.fullName, "Joy Kim"); XCTAssertEqual(p.gender, .male)
        XCTAssertEqual(FHIRMapper.dateFormatter.string(from: p.dateOfBirth), "1980-01-02"); XCTAssertEqual(p.phone, "999")
    }
    func testObservationsBloodPressurePanelAndMAP() {
        let r = VitalRecord(systolic: 120, diastolic: 80, heartRate: 70)
        let obs = FHIRMapper.observations(for: r, patientFHIRID: "P1")
        XCTAssertEqual(obs.count, 3) // BP panel, MAP, HR
        let panel = obs[0]
        XCTAssertEqual((panel["component"] as? [Any])?.count, 2)
        XCTAssertEqual((panel["subject"] as? [String: String])?["reference"], "Patient/P1")
    }
    func testObservationsOnlyForRecordedValues() {
        XCTAssertEqual(FHIRMapper.observations(for: VitalRecord(), patientFHIRID: "P").count, 0)
        XCTAssertEqual(FHIRMapper.observations(for: VitalRecord(systolic: 120), patientFHIRID: "P").count, 0, "BP needs both values")
        XCTAssertEqual(FHIRMapper.observations(for: VitalRecord(spo2: 97, painLevel: 0), patientFHIRID: "P").count, 2)
    }
    func testObservationsFullRecord() {
        let r = VitalRecord(systolic: 120, diastolic: 80, heartRate: 70, heightCm: 170, weightKg: 65, temperatureC: 36.8, respiratoryRate: 16, spo2: 98, painLevel: 1)
        XCTAssertEqual(FHIRMapper.observations(for: r, patientFHIRID: "P").count, 9)
    }
    func testObservationRoundTrip() {
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let r = VitalRecord(recordedAt: when, systolic: 118, diastolic: 76, heartRate: 66, heightCm: 171, weightKg: 70, temperatureC: 36.6, respiratoryRate: 15, spo2: 99, painLevel: 2)
        let back = FHIRMapper.vitalRecord(from: FHIRMapper.observations(for: r, patientFHIRID: "P"), recordedAt: when)
        XCTAssertEqual(back?.systolic, 118); XCTAssertEqual(back?.diastolic, 76); XCTAssertEqual(back?.heartRate, 66)
        XCTAssertEqual(back?.heightCm, 171); XCTAssertEqual(back?.weightKg, 70); XCTAssertEqual(back?.temperatureC, 36.6)
        XCTAssertEqual(back?.respiratoryRate, 15); XCTAssertEqual(back?.spo2, 99); XCTAssertEqual(back?.painLevel, 2)
    }
    func testVitalRecordFromUnknownObservationsIsNil() {
        XCTAssertNil(FHIRMapper.vitalRecord(from: [["code": ["coding": [["code": "0000-0"]]]]], recordedAt: Date()))
        XCTAssertNil(FHIRMapper.vitalRecord(from: [], recordedAt: Date()))
    }
}

final class FHIRClientTests: XCTestCase {
    func client(_ t: MockTransport, retries: Int = 2) -> FHIRClient {
        FHIRClient(baseURL: URL(string: "https://x.test/r4")!, transport: t, maxRetries: retries, retryDelay: 0.001)
    }
    func testPOSTWhenNoID() async throws {
        let t = MockTransport(); t.responses = [.success((201, ["id": "1"]))]
        let r = try await client(t).upsertPatient(["resourceType": "Patient"])
        XCTAssertEqual(r["id"] as? String, "1")
        XCTAssertEqual(t.requests[0].httpMethod, "POST")
        XCTAssertEqual(t.requests[0].url?.absoluteString, "https://x.test/r4/Patient")
        XCTAssertEqual(t.requests[0].value(forHTTPHeaderField: "Content-Type"), "application/fhir+json")
    }
    func testPUTWhenHasID() async throws {
        let t = MockTransport(); t.responses = [.success((200, ["id": "5"]))]
        _ = try await client(t).upsertPatient(["id": "5"])
        XCTAssertEqual(t.requests[0].httpMethod, "PUT")
        XCTAssertEqual(t.requests[0].url?.path, "/r4/Patient/5")
    }
    func testBearerTokenAttached() async throws {
        let t = MockTransport(); t.responses = [.success((200, ["id": "1"]))]
        var c = client(t); c.tokenProvider = { "tok" }
        _ = try await c.fetchPatient(id: "1")
        XCTAssertEqual(t.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer tok")
    }
    func testRetriesOn503ThenSucceeds() async throws {
        let t = MockTransport(); t.responses = [.success((503, [:])), .success((503, [:])), .success((200, ["id": "9"]))]
        let r = try await client(t).fetchPatient(id: "9")
        XCTAssertEqual(r["id"] as? String, "9"); XCTAssertEqual(t.requests.count, 3)
    }
    func testGivesUpAfterMaxRetries() async {
        let t = MockTransport(); t.responses = Array(repeating: .success((500, [:])), count: 10)
        do { _ = try await client(t, retries: 2).fetchPatient(id: "1"); XCTFail("expected error") }
        catch { XCTAssertEqual(error as? FHIRError, .http(500)); XCTAssertEqual(t.requests.count, 3) }
    }
    func testNoRetryOn404() async {
        let t = MockTransport(); t.responses = [.success((404, [:]))]
        do { _ = try await client(t).fetchPatient(id: "1"); XCTFail() }
        catch { XCTAssertEqual(error as? FHIRError, .http(404)); XCTAssertEqual(t.requests.count, 1) }
    }
    func testRetriesOnNetworkError() async throws {
        let t = MockTransport(); t.responses = [.failure(URLError(.notConnectedToInternet)), .success((200, ["id": "1"]))]
        _ = try await client(t).fetchPatient(id: "1")
        XCTAssertEqual(t.requests.count, 2)
    }
    func testCreateObservationReturnsID() async throws {
        let t = MockTransport(); t.responses = [.success((201, ["id": "obs1"]))]
        let id = try await client(t).createObservation(["resourceType": "Observation"])
        XCTAssertEqual(id, "obs1")
    }
    func testCreateObservationMissingIDThrowsDecoding() async {
        let t = MockTransport(); t.responses = [.success((201, [:]))]
        do { _ = try await client(t).createObservation([:]); XCTFail() } catch { XCTAssertEqual(error as? FHIRError, .decoding) }
    }
    func testFetchObservationsParsesBundle() async throws {
        let t = MockTransport(); t.responses = [.success((200, ["entry": [["resource": ["id": "a"]], ["resource": ["id": "b"]]]]))]
        let obs = try await client(t).fetchObservations(patientID: "P")
        XCTAssertEqual(obs.count, 2)
        XCTAssertTrue(t.requests[0].url!.absoluteString.contains("Observation?patient=P"))
    }
    func testFetchObservationsEmptyBundle() async throws {
        let t = MockTransport(); t.responses = [.success((200, ["resourceType": "Bundle"]))]
        let obs = try await client(t).fetchObservations(patientID: "P")
        XCTAssertTrue(obs.isEmpty)
    }
    func testRetryableStatuses() {
        for s in [408, 429, 500, 502, 503, 599] { XCTAssertTrue(FHIRClient.isRetryable(status: s), "\(s)") }
        for s in [200, 400, 401, 403, 404, 422] { XCTAssertFalse(FHIRClient.isRetryable(status: s), "\(s)") }
    }
    func testEnvironmentURLsDistinct() {
        XCTAssertEqual(Set(AppEnvironment.allCases.map(\.fhirBaseURL)).count, 3)
        XCTAssertTrue(AppEnvironment.allCases.allSatisfy { $0.fhirBaseURL.scheme == "https" }, "TLS only")
    }
    func testEnvironmentPersistence() {
        let d = UserDefaults(suiteName: "test-\(UUID())")!
        XCTAssertEqual(AppEnvironment.current(defaults: d), AppEnvironment.default)
        d.set("Staging", forKey: AppEnvironment.storageKey)
        XCTAssertEqual(AppEnvironment.current(defaults: d), .staging)
    }
}

// MARK: - SyncService

final class MockFHIR: FHIRServicing {
    var patientID = "srv1"; var obsCounter = 0; var remote: [[String: Any]] = []
    var created: [[String: Any]] = []
    var failUpsert = false
    func upsertPatient(_ json: [String: Any]) async throws -> [String: Any] {
        if failUpsert { throw FHIRError.http(500) }
        return ["id": patientID]
    }
    func fetchPatient(id: String) async throws -> [String: Any] { ["id": id, "name": [["family": "Remote", "given": ["Pat"]]]] }
    func createObservation(_ json: [String: Any]) async throws -> String { obsCounter += 1; created.append(json); return "o\(obsCounter)" }
    func fetchObservations(patientID: String) async throws -> [[String: Any]] { remote }
}

@MainActor
final class SyncServiceTests: XCTestCase {
    var container: ModelContainer!
    override func setUpWithError() throws {
        container = try ModelContainer(for: Schema([Patient.self, VitalRecord.self, AuditLogEntry.self]),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    func testPushRequiresConsent() async {
        let p = Patient(medicalID: "M1", firstName: "A", lastName: "B", dateOfBirth: Date(timeIntervalSince1970: 0))
        container.mainContext.insert(p)
        let s = SyncService(client: MockFHIR(), context: container.mainContext)
        do { try await s.push(p); XCTFail() } catch { XCTAssertEqual(error as? SyncService.SyncError, .consentRequired) }
        XCTAssertNil(p.fhirID)
    }
    func testPushUploadsPatientAndUnsyncedVitalsOnce() async throws {
        let p = Patient(medicalID: "M1", firstName: "A", lastName: "B", dateOfBirth: Date(timeIntervalSince1970: 0), consentGiven: true)
        container.mainContext.insert(p)
        let v = VitalRecord(heartRate: 70); v.patient = p; container.mainContext.insert(v)
        let mock = MockFHIR(); let s = SyncService(client: mock, context: container.mainContext)
        try await s.push(p)
        XCTAssertEqual(p.fhirID, "srv1"); XCTAssertEqual(v.fhirIDs, ["o1"])
        try await s.push(p)
        XCTAssertEqual(mock.created.count, 1, "already-synced vitals not re-uploaded")
    }
    func testPullRequiresPriorSync() async {
        let p = Patient(medicalID: "M1", firstName: "A", lastName: "B", dateOfBirth: Date(timeIntervalSince1970: 0))
        let s = SyncService(client: MockFHIR(), context: container.mainContext)
        do { try await s.pull(p); XCTFail() } catch { XCTAssertEqual(error as? SyncService.SyncError, .notSynced) }
    }
    func testPullMergesRemoteVitalsWithoutDuplicates() async throws {
        let p = Patient(medicalID: "M1", firstName: "A", lastName: "B", dateOfBirth: Date(timeIntervalSince1970: 0), consentGiven: true)
        p.fhirID = "srv1"; container.mainContext.insert(p)
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let mock = MockFHIR()
        mock.remote = FHIRMapper.observations(for: VitalRecord(recordedAt: when, heartRate: 88), patientFHIRID: "srv1").enumerated().map {
            var o = $0.element; o["id"] = "r\($0.offset)"; return o
        }
        let s = SyncService(client: mock, context: container.mainContext)
        try await s.pull(p); try await s.pull(p)
        XCTAssertEqual(p.vitals.count, 1); XCTAssertEqual(p.vitals.first?.heartRate, 88)
        XCTAssertEqual(p.lastName, "Remote")
    }

    func testPushAllConsentedSkipsNonConsentedAndCountsFailures() async throws {
        let a = Patient(medicalID: "A1X", firstName: "A", lastName: "B", dateOfBirth: Date(timeIntervalSince1970: 0), consentGiven: true)
        let b = Patient(medicalID: "B2X", firstName: "C", lastName: "D", dateOfBirth: Date(timeIntervalSince1970: 0), consentGiven: false)
        container.mainContext.insert(a); container.mainContext.insert(b)
        let mock = MockFHIR(); let s = SyncService(client: mock, context: container.mainContext)
        let failures = await s.pushAllConsented()
        XCTAssertEqual(failures, 0)
        XCTAssertEqual(a.fhirID, "srv1"); XCTAssertNil(b.fhirID, "no consent, no upload")
        mock.failUpsert = true
        let failed = await s.pushAllConsented()
        XCTAssertEqual(failed, 1)
    }
}
