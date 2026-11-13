import XCTest
@testable import PatientHealth

final class UnitConversionTests: XCTestCase {
    func testFeetInchesToCm() {
        XCTAssertEqual(UnitConversion.cm(feet: 5, inches: 10), 177.8, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.cm(feet: 0, inches: 1), 2.54, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.cm(feet: 6, inches: 0), 182.88, accuracy: 0.01)
    }
    func testCmToFeetInches() {
        let r = UnitConversion.feetAndInches(fromCm: 177.8)
        XCTAssertEqual(r.feet, 5); XCTAssertEqual(r.inches, 10, accuracy: 0.1)
    }
    func testCmToFeetInchesRollover() {
        let r = UnitConversion.feetAndInches(fromCm: 182.87)
        XCTAssertEqual(r.feet, 6); XCTAssertEqual(r.inches, 0, accuracy: 0.001)
    }
    func testHeightRoundTrip() {
        for cm in stride(from: 50.0, through: 220.0, by: 10.0) {
            let f = UnitConversion.feetAndInches(fromCm: cm)
            XCTAssertEqual(UnitConversion.cm(feet: Double(f.feet), inches: f.inches), cm, accuracy: 0.2)
        }
    }
    func testWeight() {
        XCTAssertEqual(UnitConversion.kg(fromLbs: 154.324), 70, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.lbs(fromKg: 100), 220.462, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.kg(fromLbs: 0), 0)
        for kg in [1.0, 45.5, 80, 250] { XCTAssertEqual(UnitConversion.kg(fromLbs: UnitConversion.lbs(fromKg: kg)), kg, accuracy: 1e-9) }
    }
    func testTemperature() {
        XCTAssertEqual(UnitConversion.celsius(fromFahrenheit: 98.6), 37, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.celsius(fromFahrenheit: 32), 0, accuracy: 1e-9)
        XCTAssertEqual(UnitConversion.fahrenheit(fromCelsius: 100), 212, accuracy: 1e-9)
        XCTAssertEqual(UnitConversion.fahrenheit(fromCelsius: -40), -40, accuracy: 1e-9)
    }
    func testMAP() {
        XCTAssertEqual(UnitConversion.meanArterialPressure(systolic: 120, diastolic: 80), 93.3, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.meanArterialPressure(systolic: 90, diastolic: 60), 70, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.meanArterialPressure(systolic: 140, diastolic: 90), 106.7, accuracy: 0.001)
    }
    func testRounding() {
        XCTAssertEqual(1.2345.rounded(toPlaces: 2), 1.23)
        XCTAssertEqual(2.5.rounded(toPlaces: 0), 3)
    }
}
