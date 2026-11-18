import XCTest

/// End-to-end flow: register a patient, record an abnormal reading, view the dashboard.
/// Launches with an in-memory store so runs are isolated and never touch real data.
final class PatientFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingInMemory"]
        app.launch()
    }

    func testRegisterPatientRecordVitalsAndViewDashboard() throws {
        // Empty state.
        XCTAssertTrue(app.staticTexts["No Patients"].waitForExistence(timeout: 5))

        // Register a patient.
        app.buttons["Add patient"].tap()
        let medicalID = app.textFields["Medical ID"]
        XCTAssertTrue(medicalID.waitForExistence(timeout: 5))
        medicalID.tap(); medicalID.typeText("MRN-UI-1")
        let first = app.textFields["First name"]
        first.tap(); first.typeText("Maya")
        let last = app.textFields["Last name"]
        last.tap(); last.typeText("Patel")
        app.buttons["Save"].tap()

        // The patient appears in the list; open it.
        let row = app.staticTexts["Maya Patel"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "registered patient should appear in the list")
        row.tap()

        // Record vitals with an abnormal heart rate.
        app.buttons["Enter Vitals"].tap()
        let hr = app.textFields["Heart rate (bpm)"]
        XCTAssertTrue(hr.waitForExistence(timeout: 5))
        hr.tap(); hr.typeText("130")
        let sys = app.textFields["Systolic (mmHg)"]
        sys.tap(); sys.typeText("120")
        let dia = app.textFields["Diastolic (mmHg)"]
        dia.tap(); dia.typeText("80")
        XCTAssertTrue(app.images["Abnormal value"].firstMatch.waitForExistence(timeout: 3), "abnormal flag must be exposed to accessibility, not only as colour")
        // Forms build rows lazily, so scroll the Save button into existence.
        let save = app.buttons["Save Vitals"]
        var swipes = 0
        while !save.exists && swipes < 8 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(save.exists, "Save Vitals button not reachable")
        save.tap()

        // Saving switches to the dashboard.
        XCTAssertTrue(app.buttons["Export CSV"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Export PDF"].isEnabled)
        app.buttons["Table"].tap()
        // The table row must state the value and flag it in text, not only by colour.
        let flagged = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '130.0' AND label CONTAINS 'abnormal'"))
        XCTAssertTrue(flagged.firstMatch.waitForExistence(timeout: 3), "table row should show the 130.0 reading labelled abnormal")
    }
}
