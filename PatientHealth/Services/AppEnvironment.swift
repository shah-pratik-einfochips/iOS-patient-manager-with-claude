import Foundation

// MARK: - AppEnvironment

enum AppEnvironment: String, CaseIterable, Identifiable {
    case development = "Development", staging = "Staging", production = "Production"
    var id: String { rawValue }

    /// FHIR R4 base URL for the environment.
    /// Development points at the public HAPI test server: use synthetic data only.
    /// Returns the base URL.
    var fhirBaseURL: URL {
        switch self {
        case .development: URL(string: "https://hapi.fhir.org/baseR4")!
        case .staging: URL(string: "https://staging.fhir.example.com/r4")!
        case .production: URL(string: "https://fhir.example.com/r4")!
        }
    }

    static let storageKey = "selectedEnvironment"

    /// Default environment for the build configuration.
    /// Debug builds start in Development, Release builds in Production.
    /// Returns the default environment.
    static var `default`: AppEnvironment {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }

    /// Reads the persisted environment selection.
    /// Falls back to the build default.
    /// Returns the current environment.
    static func current(defaults: UserDefaults = .standard) -> AppEnvironment {
        defaults.string(forKey: storageKey).flatMap(AppEnvironment.init(rawValue:)) ?? .default
    }
}
