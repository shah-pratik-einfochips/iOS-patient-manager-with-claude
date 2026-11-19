import XCTest
import SwiftData
@testable import PatientHealth

@MainActor
final class ModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try TestSupport.inMemoryContainer()
    }

    func makePatient() -> Patient { TestSupport.patient("MRN1", first: "Ann", last: "Lee") }

    func testSetConsentStampsKeepsAndClearsTheDate() {
        let p = makePatient()
        let first = Date(timeIntervalSince1970: 100)
        p.setConsent(true, now: first)
        XCTAssertEqual(p.consentDate, first)
        p.setConsent(true, now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(p.consentDate, first, "re-saving keeps the original consent time")
        p.setConsent(false)
        XCTAssertFalse(p.consentGiven); XCTAssertNil(p.consentDate)
    }
    func testSetValueIsTheInverseOfValueFor() {
        let r = VitalRecord()
        for t in VitalType.allCases where t != .map {
            r.setValue(42, for: t)
            XCTAssertEqual(r.value(for: t), 42, "\(t)")
        }
    }
    func testPatientDefaultsAndComputed() {
        let p = makePatient()
        XCTAssertEqual(p.fullName, "Ann Lee")
        XCTAssertEqual(p.gender, .unknown); XCTAssertEqual(p.bloodType, .unknown)
        XCTAssertEqual(p.examType, .routineCheckup); XCTAssertFalse(p.consentGiven)
    }
    func testEnumRoundTripThroughRawStorage() {
        let p = makePatient()
        p.gender = .female; p.bloodType = .abNeg; p.examType = .emergency
        XCTAssertEqual(p.genderRaw, "female"); XCTAssertEqual(p.bloodTypeRaw, "AB-"); XCTAssertEqual(p.examTypeRaw, "Emergency")
    }
    func testInvalidRawFallsBack() {
        let p = makePatient()
        p.genderRaw = "???"; p.bloodTypeRaw = "???"; p.examTypeRaw = "???"
        XCTAssertEqual(p.gender, .unknown); XCTAssertEqual(p.bloodType, .unknown); XCTAssertEqual(p.examType, .routineCheckup)
    }
    func testExaminationTypeOptionsMatchRequirement() {
        XCTAssertEqual(ExaminationType.allCases.map(\.rawValue),
                       ["Routine checkup", "Emergency", "Follow-up", "Consultation", "Diagnostic", "Preventive"])
    }
    func testPersistAndFetch() throws {
        context.insert(makePatient()); try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Patient>()).count, 1)
    }
    func testVitalsRelationshipAndCascadeDelete() throws {
        let p = makePatient(); context.insert(p)
        let v = VitalRecord(heartRate: 70); v.patient = p; context.insert(v)
        try context.save()
        XCTAssertEqual(p.vitals.count, 1)
        context.delete(p); try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<VitalRecord>()).count, 0)
    }
    func testMAPComputed() {
        XCTAssertEqual(VitalRecord(systolic: 120, diastolic: 80).map ?? 0, 93.3, accuracy: 0.01)
        XCTAssertNil(VitalRecord(systolic: 120).map)
        XCTAssertNil(VitalRecord().map)
    }
    func testValueForType() {
        let v = VitalRecord(systolic: 120, diastolic: 80, heartRate: 70, heightCm: 170, weightKg: 65, temperatureC: 36.8, respiratoryRate: 16, spo2: 98, painLevel: 2)
        let expect: [VitalType: Double] = [.systolic: 120, .diastolic: 80, .heartRate: 70, .height: 170, .weight: 65, .temperature: 36.8, .respiratoryRate: 16, .spo2: 98, .painLevel: 2]
        for (t, e) in expect { XCTAssertEqual(v.value(for: t), e, "\(t)") }
        XCTAssertNotNil(v.value(for: .map))
        XCTAssertNil(VitalRecord().value(for: .heartRate))
    }
    func testVitalTypeMetadataComplete() {
        for t in VitalType.allCases { XCTAssertFalse(t.title.isEmpty); XCTAssertFalse(t.unit.isEmpty) }
        XCTAssertFalse(VitalType.chartable.contains(.height))
    }
    func testAuditEntryPersistsViaLogger() throws {
        AuditLogger(context: context).record("test.action", detail: "x")
        let all = try context.fetch(FetchDescriptor<AuditLogEntry>())
        XCTAssertEqual(all.first?.action, "test.action")
    }

    // MARK: Unique medical ID

    func testDuplicateMedicalIDDetected() throws {
        let p = makePatient(); context.insert(p); try context.save()
        XCTAssertTrue(PatientStore.isDuplicateMedicalID("MRN1", excluding: nil, in: context))
        XCTAssertTrue(PatientStore.isDuplicateMedicalID("  MRN1 ", excluding: nil, in: context), "whitespace trimmed")
    }
    func testDifferentMedicalIDIsNotDuplicate() throws {
        context.insert(makePatient()); try context.save()
        XCTAssertFalse(PatientStore.isDuplicateMedicalID("MRN2", excluding: nil, in: context))
    }
    func testEditingSamePatientIsNotDuplicate() throws {
        let p = makePatient(); context.insert(p); try context.save()
        XCTAssertFalse(PatientStore.isDuplicateMedicalID("MRN1", excluding: p.id, in: context))
    }
    func testEditingOtherPatientToTakenIDIsDuplicate() throws {
        let a = makePatient(); context.insert(a)
        let b = TestSupport.patient("MRN2", first: "B", last: "C"); context.insert(b)
        try context.save()
        XCTAssertTrue(PatientStore.isDuplicateMedicalID("MRN1", excluding: b.id, in: context))
    }
}
