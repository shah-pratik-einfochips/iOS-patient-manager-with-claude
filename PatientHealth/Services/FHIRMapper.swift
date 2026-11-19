import Foundation

// MARK: - FHIRMapper

/// Converts between app models and FHIR R4 Patient / Observation JSON.
enum FHIRMapper {
    typealias JSON = [String: Any]

    static let medicalIDSystem = "urn:einfochips:patient-health:medical-id"
    private static let loinc = "http://loinc.org"
    private static let ucum = "http://unitsofmeasure.org"

    // MARK: Patient

    /// Builds a FHIR Patient resource.
    /// Includes identifier, name, telecom, gender, birthDate and an extension for blood type.
    /// Returns a JSON dictionary.
    static func patientResource(_ p: Patient) -> JSON {
        var telecom: [JSON] = []
        if !p.phone.isEmpty { telecom.append(["system": "phone", "value": p.phone]) }
        if !p.email.isEmpty { telecom.append(["system": "email", "value": p.email]) }
        var json: JSON = [
            "resourceType": "Patient",
            "identifier": [["system": medicalIDSystem, "value": p.medicalID]],
            "name": [["family": p.lastName, "given": [p.firstName]]],
            "gender": p.gender.rawValue,
            "birthDate": dateFormatter.string(from: p.dateOfBirth),
            "telecom": telecom,
            "extension": [["url": "urn:einfochips:patient-health:blood-type", "valueString": p.bloodType.rawValue]]
        ]
        if let id = p.fhirID { json["id"] = id }
        return json
    }

    /// Applies a FHIR Patient resource onto a model.
    /// Only fields present in the resource are updated.
    /// Returns nothing.
    static func apply(patientJSON json: JSON, to p: Patient) {
        p.fhirID = json["id"] as? String
        if let name = (json["name"] as? [JSON])?.first {
            if let family = name["family"] as? String { p.lastName = family }
            if let given = (name["given"] as? [String])?.first { p.firstName = given }
        }
        if let g = json["gender"] as? String, let gender = Gender(rawValue: g) { p.gender = gender }
        if let b = json["birthDate"] as? String, let d = dateFormatter.date(from: b) { p.dateOfBirth = d }
        for t in (json["telecom"] as? [JSON]) ?? [] {
            if t["system"] as? String == "phone", let v = t["value"] as? String { p.phone = v }
            if t["system"] as? String == "email", let v = t["value"] as? String { p.email = v }
        }
        p.updatedAt = Date()
    }

    // MARK: Observation

    private struct Spec { let type: VitalType; let code: String; let display: String; let ucum: String }
    private static let specs: [Spec] = [
        Spec(type: .heartRate, code: "8867-4", display: "Heart rate", ucum: "/min"),
        Spec(type: .height, code: "8302-2", display: "Body height", ucum: "cm"),
        Spec(type: .weight, code: "29463-7", display: "Body weight", ucum: "kg"),
        Spec(type: .temperature, code: "8310-5", display: "Body temperature", ucum: "Cel"),
        Spec(type: .respiratoryRate, code: "9279-1", display: "Respiratory rate", ucum: "/min"),
        Spec(type: .spo2, code: "59408-5", display: "Oxygen saturation by pulse oximetry", ucum: "%"),
        Spec(type: .painLevel, code: "72514-3", display: "Pain severity 0-10", ucum: "{score}")
    ]

    // Blood pressure is one panel Observation with systolic/diastolic components, plus MAP on its own.
    private static let bpPanelCode = "85354-9"
    private static let bpComponents: [Spec] = [
        Spec(type: .systolic, code: "8480-6", display: "Systolic blood pressure", ucum: "mm[Hg]"),
        Spec(type: .diastolic, code: "8462-4", display: "Diastolic blood pressure", ucum: "mm[Hg]")
    ]
    private static let meanBP = Spec(type: .map, code: "8478-0", display: "Mean blood pressure", ucum: "mm[Hg]")
    private static let vitalSignsCategory: [JSON] = [
        ["coding": [["system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "vital-signs"]]]
    ]

    /// Builds FHIR Observation resources for a vitals record.
    /// Blood pressure is one panel with systolic/diastolic components; others are one Observation each.
    /// Returns one JSON dictionary per observation.
    static func observations(for record: VitalRecord, patientFHIRID: String) -> [JSON] {
        let subject: JSON = ["reference": "Patient/\(patientFHIRID)"]
        let when = isoFormatter.string(from: record.recordedAt)
        var out: [JSON] = []

        if record.systolic != nil, record.diastolic != nil {
            var panel = envelope(code: bpPanelCode, display: "Blood pressure panel", subject: subject, when: when)
            panel["component"] = bpComponents.map { c -> JSON in
                ["code": codeable(loinc: c.code, display: c.display), "valueQuantity": quantity(record.value(for: c.type)!, c.ucum)]
            }
            out.append(panel)
            if let map = record.map { out.append(observation(meanBP, value: map, subject: subject, when: when)) }
        }
        for spec in specs {
            guard let v = record.value(for: spec.type) else { continue }
            out.append(observation(spec, value: v, subject: subject, when: when))
        }
        return out
    }

    /// Parses FHIR Observation resources into a vitals record.
    /// Observations sharing a timestamp should be passed together to build one record.
    /// Returns a record, or nil when no known vital is present.
    static func vitalRecord(from observations: [JSON], recordedAt: Date) -> VitalRecord? {
        let r = VitalRecord(recordedAt: recordedAt)
        var found = false
        for o in observations {
            let code = firstCode(of: o)
            if code == bpPanelCode {
                for c in (o["component"] as? [JSON]) ?? [] {
                    guard let spec = bpComponents.first(where: { $0.code == firstCode(of: c) }) else { continue }
                    r.setValue(quantityValue(of: c), for: spec.type)
                    found = true
                }
            } else if let spec = specs.first(where: { $0.code == code }), let v = quantityValue(of: o) {
                r.setValue(v, for: spec.type)
                found = true
            }
        }
        return found ? r : nil
    }

    // MARK: Helpers

    private static func codeable(loinc code: String, display: String) -> JSON {
        ["coding": [["system": loinc, "code": code, "display": display]], "text": display]
    }
    private static func quantity(_ v: Double, _ unit: String) -> JSON {
        ["value": v, "unit": unit, "system": ucum, "code": unit]
    }
    /// Fields every vital-signs Observation shares.
    private static func envelope(code: String, display: String, subject: JSON, when: String) -> JSON {
        ["resourceType": "Observation", "status": "final", "category": vitalSignsCategory,
         "code": codeable(loinc: code, display: display), "subject": subject, "effectiveDateTime": when]
    }
    private static func observation(_ spec: Spec, value: Double, subject: JSON, when: String) -> JSON {
        var o = envelope(code: spec.code, display: spec.display, subject: subject, when: when)
        o["valueQuantity"] = quantity(value, spec.ucum)
        return o
    }
    private static func firstCode(of o: JSON) -> String? {
        ((o["code"] as? JSON)?["coding"] as? [JSON])?.first?["code"] as? String
    }
    private static func quantityValue(of o: JSON) -> Double? {
        (o["valueQuantity"] as? JSON)?["value"] as? Double
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
}
