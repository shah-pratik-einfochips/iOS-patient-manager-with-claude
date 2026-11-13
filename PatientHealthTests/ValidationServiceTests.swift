import XCTest
@testable import PatientHealth

final class ValidationServiceTests: XCTestCase {

    // MARK: Names
    func testValidNames() {
        for n in ["Anna", "Mary-Jane", "O'Brien", "José", "Li Wei", "A"] {
            XCTAssertTrue(ValidationService.validateName(n, field: "F").isValid, n)
        }
    }
    func testInvalidNames() {
        for n in ["", "   ", "J0hn", "Bob!", "a@b", String(repeating: "x", count: 51)] {
            XCTAssertFalse(ValidationService.validateName(n, field: "F").isValid, n)
        }
    }
    func testNameMessageIncludesField() {
        XCTAssertEqual(ValidationService.validateName("", field: "Last name").message, "Last name is required")
    }

    // MARK: DOB
    func testDOBPastIsValid() { XCTAssertTrue(ValidationService.validateDateOfBirth(Date(timeIntervalSince1970: 0)).isValid) }
    func testDOBTodayIsValid() {
        let now = Date()
        XCTAssertTrue(ValidationService.validateDateOfBirth(now, now: now).isValid)
    }
    func testDOBFutureInvalid() {
        XCTAssertEqual(ValidationService.validateDateOfBirth(Date().addingTimeInterval(86400)).message, "Date of birth cannot be in the future")
    }
    func testDOBOver150YearsInvalid() {
        let d = Calendar.current.date(byAdding: .year, value: -151, to: Date())!
        XCTAssertFalse(ValidationService.validateDateOfBirth(d).isValid)
    }

    // MARK: Medical ID
    func testMedicalIDValid() {
        for id in ["ABC", "MRN-12345", "a1b2c3", String(repeating: "9", count: 20)] { XCTAssertTrue(ValidationService.validateMedicalID(id).isValid, id) }
    }
    func testMedicalIDInvalid() {
        for id in ["", "  ", "AB", "has space", "bad_id", "x!y", String(repeating: "9", count: 21)] { XCTAssertFalse(ValidationService.validateMedicalID(id).isValid, id) }
    }
    func testMedicalIDMandatoryMessage() { XCTAssertEqual(ValidationService.validateMedicalID("").message, "Medical ID is required") }

    // MARK: Phone / email
    func testPhone() {
        for p in ["", "5551234", "+1 (555) 123-4567", "+919876543210"] { XCTAssertTrue(ValidationService.validatePhone(p).isValid, p) }
        for p in ["123", "abcdefg", "1234567890123456", "555-CALL-NOW"] { XCTAssertFalse(ValidationService.validatePhone(p).isValid, p) }
    }
    func testEmail() {
        for e in ["", "a@b.co", "first.last+tag@example.com"] { XCTAssertTrue(ValidationService.validateEmail(e).isValid, e) }
        for e in ["plain", "a@b", "@b.com", "a@.com", "a b@c.com", "a@b.c"] { XCTAssertFalse(ValidationService.validateEmail(e).isValid, e) }
    }

    // MARK: Vitals ranges (boundaries)
    func testVitalBoundariesAcceptedAndRejected() {
        for t in VitalType.allCases {
            let r = t.validRange
            XCTAssertTrue(ValidationService.validateVital(r.lowerBound, type: t).isValid, "\(t) lower")
            XCTAssertTrue(ValidationService.validateVital(r.upperBound, type: t).isValid, "\(t) upper")
            XCTAssertFalse(ValidationService.validateVital(r.lowerBound - 0.1, type: t).isValid, "\(t) below")
            XCTAssertFalse(ValidationService.validateVital(r.upperBound + 0.1, type: t).isValid, "\(t) above")
        }
    }
    func testVitalRejectsNaNAndInfinity() {
        XCTAssertFalse(ValidationService.validateVital(.nan, type: .heartRate).isValid)
        XCTAssertFalse(ValidationService.validateVital(.infinity, type: .heartRate).isValid)
    }
    func testVitalMessageNamesRange() {
        XCTAssertEqual(ValidationService.validateVital(300, type: .heartRate).message, "Heart Rate must be between 20 and 250 bpm")
    }
    func testBloodPressurePair() {
        XCTAssertTrue(ValidationService.validateBloodPressurePair(systolic: 120, diastolic: 80).isValid)
        XCTAssertFalse(ValidationService.validateBloodPressurePair(systolic: 80, diastolic: 120).isValid)
        XCTAssertFalse(ValidationService.validateBloodPressurePair(systolic: 100, diastolic: 100).isValid)
    }
    func testRecordedDate() {
        XCTAssertTrue(ValidationService.validateRecordedDate(Date().addingTimeInterval(-86400 * 3)).isValid)
        XCTAssertFalse(ValidationService.validateRecordedDate(Date().addingTimeInterval(3600)).isValid)
    }

    // MARK: Abnormal
    func testAbnormalClassification() {
        XCTAssertFalse(ValidationService.isAbnormal(72, type: .heartRate))
        XCTAssertTrue(ValidationService.isAbnormal(120, type: .heartRate))
        XCTAssertTrue(ValidationService.isAbnormal(50, type: .heartRate))
        XCTAssertTrue(ValidationService.isAbnormal(38.5, type: .temperature))
        XCTAssertTrue(ValidationService.isAbnormal(90, type: .spo2))
        XCTAssertFalse(ValidationService.isAbnormal(98, type: .spo2))
        XCTAssertTrue(ValidationService.isAbnormal(8, type: .painLevel))
        XCTAssertFalse(ValidationService.isAbnormal(170, type: .height), "no normal range for height")
        XCTAssertFalse(ValidationService.isAbnormal(70, type: .weight))
    }
    func testNormalBoundariesInclusive() {
        for t in VitalType.allCases {
            guard let r = t.normalRange else { continue }
            XCTAssertFalse(ValidationService.isAbnormal(r.lowerBound, type: t))
            XCTAssertFalse(ValidationService.isAbnormal(r.upperBound, type: t))
        }
    }
}
