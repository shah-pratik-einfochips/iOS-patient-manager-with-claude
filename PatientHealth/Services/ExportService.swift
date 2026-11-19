import Foundation
import UIKit

// MARK: - ExportService

enum ExportService {

    /// Builds a CSV of vitals records.
    /// Values are in canonical units; fields containing commas or quotes are escaped.
    /// Returns the CSV text.
    static func csv(for records: [VitalRecord]) -> String {
        let types = VitalType.allCases
        var lines = [(["Date"] + types.map { "\($0.title) (\($0.unit))" } + ["Symptoms"]).map(escape).joined(separator: ",")]
        let f = ISO8601DateFormatter()
        for r in records.sorted(by: { $0.recordedAt < $1.recordedAt }) {
            let cells = [f.string(from: r.recordedAt)]
                + types.map { r.value(for: $0).map { String($0.rounded(toPlaces: 1)) } ?? "" }
                + [r.symptoms]
            lines.append(cells.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Writes a CSV to a temporary file for sharing.
    /// The file name carries no patient name to avoid leaking PHI via file names.
    /// Returns the file URL.
    static func csvFile(for records: [VitalRecord]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vitals-\(Int(Date().timeIntervalSince1970)).csv")
        try csv(for: records).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Writes the PDF report to a temporary file for sharing.
    /// The file name carries no patient name to avoid leaking PHI via file names.
    /// Returns the file URL.
    static func pdfFile(patient: Patient, records: [VitalRecord]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vitals-report-\(Int(Date().timeIntervalSince1970)).pdf")
        try pdf(patient: patient, records: records).write(to: url)
        return url
    }

    /// Renders a paginated PDF report.
    /// Includes patient header and a table of vitals, abnormal values in red.
    /// Returns the PDF data.
    static func pdf(patient: Patient, records: [VitalRecord]) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let columns: [VitalType] = [.systolic, .diastolic, .heartRate, .temperature, .respiratoryRate, .spo2, .painLevel]
        let title = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20)]
        let head = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 9)]
        let body = UIFont.systemFont(ofSize: 9)
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        let dobFormatter = DateFormatter(); dobFormatter.dateStyle = .medium; dobFormatter.timeStyle = .none
        let shortHeader: [VitalType: String] = [
            .systolic: "Sys mmHg", .diastolic: "Dia mmHg", .heartRate: "HR bpm", .temperature: "Temp °C",
            .respiratoryRate: "Resp /min", .spo2: "SpO₂ %", .painLevel: "Pain /10"
        ]

        return renderer.pdfData { ctx in
            var y: CGFloat = 0
            func newPage() {
                ctx.beginPage()
                y = 40
                "Vitals Report".draw(at: CGPoint(x: 40, y: y), withAttributes: title); y += 30
                "\(patient.fullName) · ID \(patient.medicalID) · DOB \(dobFormatter.string(from: patient.dateOfBirth))"
                    .draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: body]); y += 24
                draw(["Date"] + columns.map { shortHeader[$0] ?? $0.title }, y: y, attrs: head)
                y += 16
            }
            func draw(_ cells: [String], y: CGFloat, attrs: [NSAttributedString.Key: Any], abnormal: Set<Int> = []) {
                // The date column is wider (1.7 units) so the time of day is not truncated.
                let w: CGFloat = (page.width - 80) / (CGFloat(cells.count - 1) + 1.7)
                for (i, c) in cells.enumerated() {
                    var a = attrs
                    if abnormal.contains(i) { a[.foregroundColor] = UIColor.red }
                    let x = i == 0 ? 40 : 40 + w * 1.7 + CGFloat(i - 1) * w
                    c.draw(in: CGRect(x: x, y: y, width: (i == 0 ? w * 1.7 : w) - 4, height: 14), withAttributes: a)
                }
            }
            newPage()
            for r in records.sorted(by: { $0.recordedAt < $1.recordedAt }) {
                if y > page.height - 60 { newPage() }
                var abnormal = Set<Int>()
                var cells = [df.string(from: r.recordedAt)]
                for (i, t) in columns.enumerated() {
                    let v = r.value(for: t)
                    let isBad = v.map { ValidationService.isAbnormal($0, type: t) } ?? false
                    cells.append(v.map { String($0.rounded(toPlaces: 1)) + (isBad ? "*" : "") } ?? "–")
                    if isBad { abnormal.insert(i + 1) }
                }
                draw(cells, y: y, attrs: [.font: body], abnormal: abnormal)
                y += 15
            }
        }
    }

    private static func escape(_ s: String) -> String {
        guard s.contains(where: { ",\"\n".contains($0) }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
