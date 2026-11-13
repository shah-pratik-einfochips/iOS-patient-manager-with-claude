import Foundation

// MARK: - ValidationResult

enum ValidationResult: Equatable {
    case valid
    case invalid(String)

    var isValid: Bool { self == .valid }
    var message: String? { if case .invalid(let m) = self { m } else { nil } }
}

// MARK: - ValidationService

enum ValidationService {

    /// Validates a required person name.
    /// Allows letters, spaces, hyphens and apostrophes up to 50 characters.
    /// Returns .valid or .invalid with a message.
    static func validateName(_ value: String, field: String) -> ValidationResult {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return .invalid("\(field) is required") }
        guard v.count <= 50 else { return .invalid("\(field) must be 50 characters or fewer") }
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: " -'"))
        guard v.unicodeScalars.allSatisfy(allowed.contains) else {
            return .invalid("\(field) contains invalid characters")
        }
        return .valid
    }

    /// Validates date of birth.
    /// Must not be in the future and not more than 150 years ago.
    /// Returns .valid or .invalid with a message.
    static func validateDateOfBirth(_ dob: Date, now: Date = Date()) -> ValidationResult {
        guard dob <= now else { return .invalid("Date of birth cannot be in the future") }
        let limit = Calendar.current.date(byAdding: .year, value: -150, to: now) ?? .distantPast
        guard dob >= limit else { return .invalid("Date of birth is too far in the past") }
        return .valid
    }

    /// Validates the mandatory medical ID.
    /// Must be 3–20 alphanumeric characters (hyphens allowed).
    /// Returns .valid or .invalid with a message.
    static func validateMedicalID(_ value: String) -> ValidationResult {
        let v = value.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return .invalid("Medical ID is required") }
        guard (3...20).contains(v.count) else { return .invalid("Medical ID must be 3–20 characters") }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard v.unicodeScalars.allSatisfy(allowed.contains) else {
            return .invalid("Medical ID may only contain letters, numbers and hyphens")
        }
        return .valid
    }

    /// Validates an optional phone number.
    /// Accepts 7–15 digits with optional +, spaces, dashes and parentheses.
    /// Returns .valid (also when empty) or .invalid with a message.
    static func validatePhone(_ value: String) -> ValidationResult {
        let v = value.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return .valid }
        let allowed = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+-() "))
        guard v.unicodeScalars.allSatisfy(allowed.contains) else { return .invalid("Phone number contains invalid characters") }
        let digits = v.filter(\.isNumber).count
        guard (7...15).contains(digits) else { return .invalid("Phone number must have 7–15 digits") }
        return .valid
    }

    /// Validates an optional email address.
    /// Uses a pragmatic pattern, not full RFC 5322.
    /// Returns .valid (also when empty) or .invalid with a message.
    static func validateEmail(_ value: String) -> ValidationResult {
        let v = value.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return .valid }
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        guard v.range(of: pattern, options: .regularExpression) != nil else { return .invalid("Enter a valid email address") }
        return .valid
    }

    /// Validates a vital value in canonical units.
    /// Rejects values outside the type's hard limits.
    /// Returns .valid or .invalid with a message naming the range.
    static func validateVital(_ value: Double, type: VitalType) -> ValidationResult {
        let r = type.validRange
        guard value.isFinite, r.contains(value) else {
            return .invalid("\(type.title) must be between \(format(r.lowerBound)) and \(format(r.upperBound)) \(type.unit)")
        }
        return .valid
    }

    /// Validates that diastolic is lower than systolic.
    /// Guards against swapped blood-pressure entries.
    /// Returns .valid or .invalid with a message.
    static func validateBloodPressurePair(systolic: Double, diastolic: Double) -> ValidationResult {
        diastolic < systolic ? .valid : .invalid("Diastolic must be lower than systolic")
    }

    /// Validates the vitals measurement date.
    /// Past dates are allowed, future dates are not.
    /// Returns .valid or .invalid with a message.
    static func validateRecordedDate(_ date: Date, now: Date = Date()) -> ValidationResult {
        date <= now.addingTimeInterval(60) ? .valid : .invalid("Measurement date cannot be in the future")
    }

    /// Classifies a value against its normal range.
    /// Used to flag abnormal vitals in forms and dashboard.
    /// Returns true when outside the normal range.
    static func isAbnormal(_ value: Double, type: VitalType) -> Bool {
        guard let r = type.normalRange else { return false }
        return !r.contains(value)
    }

    private static func format(_ v: Double) -> String { v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v) }
}
