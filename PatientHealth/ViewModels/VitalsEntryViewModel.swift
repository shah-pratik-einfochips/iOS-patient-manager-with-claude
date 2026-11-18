import Foundation
import Observation

// MARK: - VitalsEntryViewModel

@Observable
final class VitalsEntryViewModel {
    var recordedAt = Date()
    var systolic = ""
    var diastolic = ""
    var heartRate = ""
    var heightUnit: HeightUnit = .cm
    var heightCm = ""
    var heightFeet = ""
    var heightInches = ""
    var weightUnit: WeightUnit = .kg
    var weight = ""
    var temperatureUnit: TemperatureUnit = .celsius
    var temperature = ""
    var respiratoryRate = ""
    var spo2 = ""
    var painLevel = 0.0
    var painEntered = false
    var symptoms = ""

    private func number(_ s: String) -> Double? { Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }

    // MARK: Canonical values

    var systolicValue: Double? { number(systolic) }
    var diastolicValue: Double? { number(diastolic) }
    var heartRateValue: Double? { number(heartRate) }
    var respiratoryRateValue: Double? { number(respiratoryRate) }
    var spo2Value: Double? { number(spo2) }

    /// Height in centimeters from the selected unit.
    /// Returns nil when the field is empty or non-numeric.
    var heightValueCm: Double? {
        switch heightUnit {
        case .cm: return number(heightCm)
        case .ftIn:
            guard let f = number(heightFeet) else { return nil }
            return UnitConversion.cm(feet: f, inches: number(heightInches) ?? 0)
        }
    }

    /// Weight in kilograms from the selected unit.
    /// Returns nil when the field is empty or non-numeric.
    var weightValueKg: Double? { number(weight).map { weightUnit == .kg ? $0 : UnitConversion.kg(fromLbs: $0) } }

    /// Temperature in Celsius from the selected unit.
    /// Returns nil when the field is empty or non-numeric.
    var temperatureValueC: Double? { number(temperature).map { temperatureUnit == .celsius ? $0 : UnitConversion.celsius(fromFahrenheit: $0) } }

    /// Auto-calculated mean arterial pressure.
    /// Updates live as systolic and diastolic change.
    /// Returns nil until both are valid numbers.
    var mapValue: Double? {
        guard let s = systolicValue, let d = diastolicValue else { return nil }
        return UnitConversion.meanArterialPressure(systolic: s, diastolic: d)
    }

    // MARK: Validation

    /// Validates an optional field, ignoring empty input.
    /// Non-numeric text is reported as an error.
    /// Returns an error message or nil.
    func error(raw: String, value: Double?, type: VitalType) -> String? {
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let value else { return "Enter a number" }
        return ValidationService.validateVital(value, type: type).message
    }

    var systolicError: String? { error(raw: systolic, value: systolicValue, type: .systolic) }
    var diastolicError: String? {
        if let e = error(raw: diastolic, value: diastolicValue, type: .diastolic) { return e }
        if let s = systolicValue, let d = diastolicValue { return ValidationService.validateBloodPressurePair(systolic: s, diastolic: d).message }
        return nil
    }
    var pairError: String? {
        (systolic.isEmpty != diastolic.isEmpty) ? "Enter both systolic and diastolic" : nil
    }
    var heartRateError: String? { error(raw: heartRate, value: heartRateValue, type: .heartRate) }
    var heightError: String? {
        let raw = heightUnit == .cm ? heightCm : heightFeet
        return error(raw: raw, value: heightValueCm, type: .height)
    }
    var weightError: String? { error(raw: weight, value: weightValueKg, type: .weight) }
    var temperatureError: String? { error(raw: temperature, value: temperatureValueC, type: .temperature) }
    var respiratoryError: String? { error(raw: respiratoryRate, value: respiratoryRateValue, type: .respiratoryRate) }
    var spo2Error: String? { error(raw: spo2, value: spo2Value, type: .spo2) }
    var dateError: String? { ValidationService.validateRecordedDate(recordedAt).message }

    /// Whether at least one vital has been entered.
    /// Prevents saving empty records.
    /// Returns true when there is data to save.
    var hasAnyValue: Bool {
        [systolicValue, heartRateValue, heightValueCm, weightValueKg, temperatureValueC, respiratoryRateValue, spo2Value].contains { $0 != nil }
            || painEntered || !symptoms.isEmpty
    }

    /// Whether the entry can be saved.
    /// Requires at least one value and no validation errors.
    /// Returns true when valid.
    var canSave: Bool {
        hasAnyValue && [systolicError, diastolicError, pairError, heartRateError, heightError, weightError,
                        temperatureError, respiratoryError, spo2Error, dateError].allSatisfy { $0 == nil }
    }

    /// Whether the typed value is outside the normal range.
    /// Drives the visual abnormal indicator beside each field.
    /// Returns true if abnormal.
    func isAbnormal(_ value: Double?, _ type: VitalType) -> Bool {
        guard let value, ValidationService.validateVital(value, type: type).isValid else { return false }
        return ValidationService.isAbnormal(value, type: type)
    }

    /// `isAbnormal` for the form's own value of a type, so a field can't be checked against the wrong value.
    func isAbnormal(_ type: VitalType) -> Bool { isAbnormal(value(for: type), type) }

    private func value(for type: VitalType) -> Double? {
        switch type {
        case .systolic: systolicValue
        case .diastolic: diastolicValue
        case .map: mapValue
        case .heartRate: heartRateValue
        case .height: heightValueCm
        case .weight: weightValueKg
        case .temperature: temperatureValueC
        case .respiratoryRate: respiratoryRateValue
        case .spo2: spo2Value
        case .painLevel: painEntered ? painLevel : nil
        }
    }

    /// Builds a VitalRecord in canonical units.
    /// Callers should check canSave first.
    /// Returns an unsaved record.
    func makeRecord() -> VitalRecord {
        VitalRecord(recordedAt: recordedAt, systolic: systolicValue, diastolic: diastolicValue,
                    heartRate: heartRateValue, heightCm: heightValueCm?.rounded(toPlaces: 1),
                    weightKg: weightValueKg?.rounded(toPlaces: 1), temperatureC: temperatureValueC?.rounded(toPlaces: 1),
                    respiratoryRate: respiratoryRateValue, spo2: spo2Value,
                    painLevel: painEntered ? painLevel : nil, symptoms: symptoms)
    }
}
