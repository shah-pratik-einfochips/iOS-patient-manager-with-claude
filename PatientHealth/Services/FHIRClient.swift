import Foundation

// MARK: - HTTPTransport

protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    /// Sends a request and requires an HTTP response.
    /// Adapts URLSession to the HTTPTransport abstraction for testing.
    /// Returns the body and response.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FHIRError.invalidResponse }
        return (data, http)
    }
}

// MARK: - FHIRError

enum FHIRError: LocalizedError, Equatable {
    case invalidResponse
    case http(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an invalid response."
        case .http(let c): "The server responded with status \(c)."
        case .decoding: "The server response could not be read."
        }
    }
}

// MARK: - FHIRServicing

protocol FHIRServicing {
    func upsertPatient(_ json: [String: Any]) async throws -> [String: Any]
    func fetchPatient(id: String) async throws -> [String: Any]
    func createObservation(_ json: [String: Any]) async throws -> String
    func fetchObservations(patientID: String) async throws -> [[String: Any]]
}

// MARK: - FHIRClient

struct FHIRClient: FHIRServicing {
    let baseURL: URL
    var transport: HTTPTransport = {
        let c = URLSessionConfiguration.default
        c.tlsMinimumSupportedProtocolVersion = .TLSv12
        c.timeoutIntervalForRequest = 30
        return URLSession(configuration: c)
    }()
    var maxRetries = 3
    var retryDelay: TimeInterval = 0.5
    var tokenProvider: () -> String? = { nil }

    /// Creates or updates a Patient.
    /// PUTs when the resource has an id, otherwise POSTs.
    /// Returns the stored resource including its server id.
    func upsertPatient(_ json: [String: Any]) async throws -> [String: Any] {
        if let id = json["id"] as? String {
            return try await request("Patient/\(id)", method: "PUT", body: json)
        }
        return try await request("Patient", method: "POST", body: json)
    }

    /// Retrieves a Patient by server id.
    /// Used to refresh local demographics.
    /// Returns the Patient resource.
    func fetchPatient(id: String) async throws -> [String: Any] {
        try await request("Patient/\(id)", method: "GET", body: nil)
    }

    /// Creates an Observation.
    /// Observations are immutable once recorded, so only POST is used.
    /// Returns the server-assigned id.
    func createObservation(_ json: [String: Any]) async throws -> String {
        let r = try await request("Observation", method: "POST", body: json)
        guard let id = r["id"] as? String else { throw FHIRError.decoding }
        return id
    }

    /// Retrieves vital-sign Observations for a patient.
    /// Reads the first page of a searchset Bundle, newest first.
    /// Returns the Observation resources.
    func fetchObservations(patientID: String) async throws -> [[String: Any]] {
        let bundle = try await request("Observation?patient=\(patientID)&category=vital-signs&_sort=-date&_count=100", method: "GET", body: nil)
        return ((bundle["entry"] as? [[String: Any]]) ?? []).compactMap { $0["resource"] as? [String: Any] }
    }

    // MARK: Request + retry

    private func request(_ path: String, method: String, body: [String: Any]?) async throws -> [String: Any] {
        guard let url = URL(string: path, relativeTo: baseURL.appendingPathComponent("")) else { throw FHIRError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/fhir+json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if let token = tokenProvider() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        var attempt = 0
        while true {
            do {
                let (data, response) = try await transport.send(req)
                if (200..<300).contains(response.statusCode) {
                    guard !data.isEmpty else { return [:] }
                    guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw FHIRError.decoding }
                    return obj
                }
                if Self.isRetryable(status: response.statusCode), attempt < maxRetries {
                    attempt += 1
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * pow(2, Double(attempt - 1)) * 1_000_000_000))
                    continue
                }
                throw FHIRError.http(response.statusCode)
            } catch let error as URLError where attempt < maxRetries && error.code != .cancelled {
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(retryDelay * pow(2, Double(attempt - 1)) * 1_000_000_000))
            }
        }
    }

    /// Decides whether an HTTP status should be retried.
    /// Retries transient server errors and rate limiting only.
    /// Returns true for 408, 429 and 5xx.
    static func isRetryable(status: Int) -> Bool { status == 408 || status == 429 || (500...599).contains(status) }
}
