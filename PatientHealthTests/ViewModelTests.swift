import XCTest
@testable import PatientHealth

final class PatientFormViewModelTests: XCTestCase {
    func filled() -> PatientFormViewModel {
        let vm = PatientFormViewModel(); vm.medicalID = "MRN-1"; vm.firstName = "Ann"; vm.lastName = "Lee"; return vm
    }
    func testEmptyFormInvalid() { XCTAssertFalse(PatientFormViewModel().isValid) }
    func testFilledFormValid() { XCTAssertTrue(filled().isValid) }
    func testEachRequiredFieldBlocksSave() {
        var vm = filled(); vm.medicalID = ""; XCTAssertFalse(vm.isValid)
        vm = filled(); vm.firstName = ""; XCTAssertFalse(vm.isValid)
        vm = filled(); vm.lastName = ""; XCTAssertFalse(vm.isValid)
    }
    func testFutureDOBBlocksSave() { let vm = filled(); vm.dateOfBirth = Date().addingTimeInterval(86400 * 30); XCTAssertNotNil(vm.dobError); XCTAssertFalse(vm.isValid) }
    func testBadOptionalFieldsBlockSave() {
        var vm = filled(); vm.email = "nope"; XCTAssertFalse(vm.isValid)
        vm = filled(); vm.phone = "12"; XCTAssertFalse(vm.isValid)
    }
    func testMakePatientCopiesAndTrims() {
        let vm = filled(); vm.firstName = "  Ann "; vm.gender = .female; vm.examType = .followUp; vm.allergies = "Penicillin"
        let p = vm.makePatient()
        XCTAssertEqual(p.firstName, "Ann"); XCTAssertEqual(p.gender, .female); XCTAssertEqual(p.examType, .followUp); XCTAssertEqual(p.allergies, "Penicillin")
    }
    func testConsentTimestamp() {
        let vm = filled(); vm.consentGiven = true
        let p = vm.makePatient()
        XCTAssertTrue(p.consentGiven); XCTAssertNotNil(p.consentDate)
        let vm2 = PatientFormViewModel(patient: p); vm2.consentGiven = false; vm2.apply(to: p)
        XCTAssertFalse(p.consentGiven); XCTAssertNil(p.consentDate, "withdrawal clears consent date")
    }
    func testEditRoundTrip() {
        let p = filled().makePatient(); p.ethnicity = "X"
        XCTAssertEqual(PatientFormViewModel(patient: p).ethnicity, "X")
    }
}

final class VitalsEntryViewModelTests: XCTestCase {
    func testEmptyCannotSave() { XCTAssertFalse(VitalsEntryViewModel().canSave) }
    func testMAPLiveCalculation() {
        let vm = VitalsEntryViewModel(); vm.systolic = "120"; vm.diastolic = "80"
        XCTAssertEqual(vm.mapValue ?? 0, 93.3, accuracy: 0.01)
        vm.diastolic = ""; XCTAssertNil(vm.mapValue)
    }
    func testBPNeedsBothValues() { let vm = VitalsEntryViewModel(); vm.systolic = "120"; XCTAssertNotNil(vm.pairError); XCTAssertFalse(vm.canSave) }
    func testDiastolicAboveSystolicInvalid() { let vm = VitalsEntryViewModel(); vm.systolic = "80"; vm.diastolic = "120"; XCTAssertNotNil(vm.diastolicError); XCTAssertFalse(vm.canSave) }
    func testNonNumericInvalid() { let vm = VitalsEntryViewModel(); vm.heartRate = "abc"; XCTAssertEqual(vm.heartRateError, "Enter a number"); XCTAssertFalse(vm.canSave) }
    func testOutOfRangeInvalid() { let vm = VitalsEntryViewModel(); vm.spo2 = "101"; XCTAssertNotNil(vm.spo2Error); XCTAssertFalse(vm.canSave) }
    func testDecimalCommaAccepted() { let vm = VitalsEntryViewModel(); vm.temperature = "36,8"; XCTAssertEqual(vm.temperatureValueC ?? 0, 36.8, accuracy: 0.001) }
    func testHeightUnits() {
        let vm = VitalsEntryViewModel(); vm.heightCm = "170"; XCTAssertEqual(vm.heightValueCm, 170)
        vm.heightUnit = .ftIn; vm.heightFeet = "5"; vm.heightInches = "10"; XCTAssertEqual(vm.heightValueCm ?? 0, 177.8, accuracy: 0.01)
        vm.heightInches = ""; XCTAssertEqual(vm.heightValueCm ?? 0, 152.4, accuracy: 0.01)
        vm.heightFeet = ""; XCTAssertNil(vm.heightValueCm)
    }
    func testWeightUnits() {
        let vm = VitalsEntryViewModel(); vm.weight = "70"; XCTAssertEqual(vm.weightValueKg, 70)
        vm.weightUnit = .lbs; vm.weight = "154.32"; XCTAssertEqual(vm.weightValueKg ?? 0, 70, accuracy: 0.01)
    }
    func testTemperatureUnits() {
        let vm = VitalsEntryViewModel(); vm.temperatureUnit = .fahrenheit; vm.temperature = "98.6"
        XCTAssertEqual(vm.temperatureValueC ?? 0, 37, accuracy: 0.01); XCTAssertNil(vm.temperatureError)
        vm.temperature = "200"; XCTAssertNotNil(vm.temperatureError)
    }
    func testFutureDateInvalid() { let vm = VitalsEntryViewModel(); vm.heartRate = "70"; vm.recordedAt = Date().addingTimeInterval(86400); XCTAssertFalse(vm.canSave) }
    func testPastDateAllowed() { let vm = VitalsEntryViewModel(); vm.heartRate = "70"; vm.recordedAt = Date().addingTimeInterval(-86400 * 5); XCTAssertTrue(vm.canSave) }
    func testPainAloneCanSave() { let vm = VitalsEntryViewModel(); vm.painEntered = true; vm.painLevel = 0; XCTAssertTrue(vm.canSave) }
    func testSymptomsAloneCanSave() { let vm = VitalsEntryViewModel(); vm.symptoms = "Cough"; XCTAssertTrue(vm.canSave) }
    func testAbnormalIndicator() {
        let vm = VitalsEntryViewModel()
        XCTAssertTrue(vm.isAbnormal(130, .heartRate)); XCTAssertFalse(vm.isAbnormal(70, .heartRate))
        XCTAssertFalse(vm.isAbnormal(999, .heartRate), "invalid values show an error, not an abnormal flag")
        XCTAssertFalse(vm.isAbnormal(nil, .heartRate))
    }
    func testMakeRecordStoresCanonicalUnits() {
        let vm = VitalsEntryViewModel()
        vm.systolic = "120"; vm.diastolic = "80"; vm.heartRate = "72"; vm.weightUnit = .lbs; vm.weight = "154.32"
        vm.temperatureUnit = .fahrenheit; vm.temperature = "98.6"; vm.painEntered = true; vm.painLevel = 3
        let r = vm.makeRecord()
        XCTAssertEqual(r.systolic, 120); XCTAssertEqual(r.weightKg ?? 0, 70, accuracy: 0.05)
        XCTAssertEqual(r.temperatureC ?? 0, 37, accuracy: 0.05); XCTAssertEqual(r.painLevel, 3); XCTAssertNil(r.spo2)
    }
    func testPainNilWhenNotEntered() { let vm = VitalsEntryViewModel(); vm.heartRate = "70"; XCTAssertNil(vm.makeRecord().painLevel) }
}

final class DashboardViewModelTests: XCTestCase {
    let vm = DashboardViewModel()
    func rec(_ daysAgo: Double, hr: Double?) -> VitalRecord { VitalRecord(recordedAt: Date().addingTimeInterval(-86400 * daysAgo), heartRate: hr) }

    func testRecentFiltersToSevenDaysSorted() {
        let out = vm.recent([rec(1, hr: 1), rec(10, hr: 2), rec(6.9, hr: 3), rec(0.1, hr: 4)])
        XCTAssertEqual(out.map(\.heartRate), [3, 1, 4])
    }
    func testRecentExcludesFuture() { XCTAssertTrue(vm.recent([rec(-1, hr: 1)]).isEmpty) }
    func testPointsSkipMissingAndFlagAbnormal() {
        let pts = vm.points([rec(1, hr: 70), rec(2, hr: nil), rec(3, hr: 130)], type: .heartRate)
        XCTAssertEqual(pts.count, 2); XCTAssertEqual(pts.filter(\.abnormal).count, 1)
    }
    func testStats() {
        let s = vm.stats([rec(3, hr: 60), rec(2, hr: 80), rec(1, hr: 100)], type: .heartRate)
        XCTAssertEqual(s, .init(min: 60, max: 100, average: 80, latest: 100, count: 3))
    }
    func testStatsNilWhenNoData() { XCTAssertNil(vm.stats([rec(1, hr: nil)], type: .heartRate)); XCTAssertNil(vm.stats([], type: .spo2)) }
}

final class ExportServiceTests: XCTestCase {
    func testCSVHeaderAndRows() {
        let csv = ExportService.csv(for: [VitalRecord(heartRate: 72, symptoms: "Cough")])
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("Date,Systolic BP (mmHg)"))
        XCTAssertTrue(lines[1].contains("72.0")); XCTAssertTrue(lines[1].hasSuffix("Cough"))
    }
    func testCSVEscapesCommasQuotesNewlines() {
        let csv = ExportService.csv(for: [VitalRecord(symptoms: "a, \"b\"\nc")])
        XCTAssertTrue(csv.contains("\"a, \"\"b\"\"\nc\""))
    }
    func testCSVSortedAscending() {
        let a = VitalRecord(recordedAt: Date(timeIntervalSince1970: 200), heartRate: 2)
        let b = VitalRecord(recordedAt: Date(timeIntervalSince1970: 100), heartRate: 1)
        let rows = ExportService.csv(for: [a, b]).split(separator: "\n")
        XCTAssertTrue(rows[1].contains("1.0")); XCTAssertTrue(rows[2].contains("2.0"))
    }
    func testCSVEmpty() { XCTAssertEqual(ExportService.csv(for: []).split(separator: "\n").count, 1) }
    func testPDFProducesValidPDF() {
        let p = TestSupport.patient("M")
        let data = ExportService.pdf(patient: p, records: (0..<80).map { VitalRecord(heartRate: Double(60 + $0 % 50)) })
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "%PDF")
        XCTAssertGreaterThan(data.count, 1000)
    }
    func testCSVFileNameHasNoPHI() throws {
        let url = try ExportService.csvFile(for: [VitalRecord(heartRate: 70)])
        XCTAssertTrue(url.lastPathComponent.hasPrefix("vitals-")); XCTAssertEqual(url.pathExtension, "csv")
    }
}

final class KeychainServiceTests: XCTestCase {
    func testSaveLoadDelete() throws {
        let k = KeychainService(service: "test.\(UUID())")
        XCTAssertNil(k.load("t"))
        try k.save(Data("secret".utf8), for: "t")
        XCTAssertEqual(k.load("t"), Data("secret".utf8))
        try k.save(Data("new".utf8), for: "t")
        XCTAssertEqual(k.load("t"), Data("new".utf8), "overwrites")
        k.delete("t"); XCTAssertNil(k.load("t"))
    }
}
