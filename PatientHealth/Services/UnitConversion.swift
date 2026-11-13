import Foundation

// MARK: - Unit enums

enum HeightUnit: String, CaseIterable, Identifiable { case cm, ftIn = "ft/in"; var id: String { rawValue } }
enum WeightUnit: String, CaseIterable, Identifiable { case kg, lbs; var id: String { rawValue } }
enum TemperatureUnit: String, CaseIterable, Identifiable { case celsius = "°C", fahrenheit = "°F"; var id: String { rawValue } }

// MARK: - UnitConversion

enum UnitConversion {
    static let cmPerInch = 2.54
    static let lbsPerKg = 2.20462262185

    /// Converts feet and inches to centimeters.
    /// Used when height is entered in imperial units.
    /// Returns centimeters.
    static func cm(feet: Double, inches: Double) -> Double { (feet * 12 + inches) * cmPerInch }

    /// Splits centimeters into whole feet and remaining inches.
    /// Used when displaying stored height in imperial units.
    /// Returns a (feet, inches) tuple with inches rounded to one decimal.
    static func feetAndInches(fromCm cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / cmPerInch
        var feet = Int(totalInches / 12)
        var inches = (totalInches - Double(feet) * 12).rounded(toPlaces: 1)
        if inches >= 12 { feet += 1; inches = 0 }
        return (feet, inches)
    }

    /// Converts pounds to kilograms.
    /// Used when weight is entered in lbs.
    /// Returns kilograms.
    static func kg(fromLbs lbs: Double) -> Double { lbs / lbsPerKg }

    /// Converts kilograms to pounds.
    /// Used when displaying weight in lbs.
    /// Returns pounds.
    static func lbs(fromKg kg: Double) -> Double { kg * lbsPerKg }

    /// Converts Fahrenheit to Celsius.
    /// Used when temperature is entered in °F.
    /// Returns degrees Celsius.
    static func celsius(fromFahrenheit f: Double) -> Double { (f - 32) * 5 / 9 }

    /// Converts Celsius to Fahrenheit.
    /// Used when displaying temperature in °F.
    /// Returns degrees Fahrenheit.
    static func fahrenheit(fromCelsius c: Double) -> Double { c * 9 / 5 + 32 }

    /// Calculates mean arterial pressure.
    /// Uses MAP = (SBP + 2 × DBP) / 3.
    /// Returns MAP in mmHg rounded to one decimal.
    static func meanArterialPressure(systolic: Double, diastolic: Double) -> Double {
        ((systolic + 2 * diastolic) / 3).rounded(toPlaces: 1)
    }
}

extension Double {
    /// Rounds to a number of decimal places.
    /// Keeps displayed and stored values tidy.
    /// Returns the rounded value.
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
