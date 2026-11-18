import SwiftUI
import Charts

// MARK: - DashboardView

struct DashboardView: View {
    let patient: Patient
    @Environment(\.modelContext) private var context
    @State private var vm = DashboardViewModel()
    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    struct ShareItem: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        let records = vm.recent(patient.vitals)
        VStack(spacing: 12) {
            HStack {
                Picker("Vital", selection: $vm.selectedType) { ForEach(VitalType.chartable) { Text($0.title).tag($0) } }
                Spacer()
                Picker("View", selection: $vm.showChart) {
                    Text("Chart").tag(true); Text("Table").tag(false)
                }.pickerStyle(.segmented).frame(maxWidth: 180)
            }.padding(.horizontal)

            HStack {
                Button("Export CSV") { export(csv: true, records: records) }
                Button("Export PDF") { export(csv: false, records: records) }
            }
            .buttonStyle(.bordered)
            .disabled(records.isEmpty)
            .accessibilityHint("Opens the share sheet")

            if records.isEmpty {
                ContentUnavailableView("No Vitals in the Last 7 Days", systemImage: "waveform.path.ecg")
            } else {
                statsView(records)
                if vm.showChart { chart(records) } else { table(records) }
            }
        }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(exportError ?? "") }
    }

    private func statsView(_ records: [VitalRecord]) -> some View {
        Group {
            if let s = vm.stats(records, type: vm.selectedType) {
                let unit = vm.selectedType.unit
                HStack {
                    stat("Latest", s.latest, unit, abnormal: ValidationService.isAbnormal(s.latest, type: vm.selectedType))
                    stat("Min", s.min, unit); stat("Max", s.max, unit); stat("Avg", s.average, unit)
                }.padding(.horizontal)
            } else {
                Text("No \(vm.selectedType.title) readings").foregroundStyle(.secondary)
            }
        }
    }

    private func stat(_ title: String, _ v: Double, _ unit: String, abnormal: Bool = false) -> some View {
        VStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(String(format: "%.1f", v) + (abnormal ? " ⚠" : "")).font(.headline).foregroundStyle(abnormal ? .red : .primary)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(String(format: "%.1f", v)) \(unit)\(abnormal ? ", abnormal" : "")")
    }

    private func chart(_ records: [VitalRecord]) -> some View {
        let pts = vm.points(records, type: vm.selectedType)
        return Chart {
            if let r = vm.selectedType.normalRange {
                RectangleMark(yStart: .value("Low", r.lowerBound), yEnd: .value("High", r.upperBound))
                    .foregroundStyle(.green.opacity(0.12))
            }
            ForEach(pts) { p in
                LineMark(x: .value("Date", p.date), y: .value(vm.selectedType.title, p.value)).foregroundStyle(.blue)
                PointMark(x: .value("Date", p.date), y: .value(vm.selectedType.title, p.value))
                    .foregroundStyle(p.abnormal ? .red : .blue)
                    .symbol(p.abnormal ? BasicChartSymbolShape.diamond : BasicChartSymbolShape.circle)
                    .symbolSize(p.abnormal ? 130 : 50)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel(vm.selectedType.unit)
        .padding()
        .accessibilityLabel(chartSummary(pts))
        .accessibilityHint("Switch to Table for individual readings")
    }

    private func chartSummary(_ pts: [DashboardViewModel.Point]) -> String {
        guard let lo = pts.map(\.value).min(), let hi = pts.map(\.value).max() else { return "\(vm.selectedType.title) line chart, no readings" }
        let unit = vm.selectedType.unit
        return "\(vm.selectedType.title) line chart, \(pts.count) readings from \(String(format: "%.1f", lo)) to \(String(format: "%.1f", hi)) \(unit), \(pts.filter(\.abnormal).count) abnormal."
    }

    private func table(_ records: [VitalRecord]) -> some View {
        List(records.reversed()) { r in
            VStack(alignment: .leading, spacing: 4) {
                Text(r.recordedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading) {
                    ForEach(VitalType.allCases) { t in
                        if let v = r.value(for: t) {
                            let bad = ValidationService.isAbnormal(v, type: t)
                            Text("\(t.title): \(String(format: "%.1f", v)) \(t.unit)" + (bad ? "  ⚠ abnormal" : ""))
                                .font(.caption).foregroundStyle(bad ? .red : .primary)
                                .accessibilityLabel("\(t.title) \(String(format: "%.1f", v)) \(t.unit)\(bad ? ", abnormal" : "")")
                        }
                    }
                }
            }
        }
    }

    /// Exports the visible records and presents the share sheet.
    /// Logs the export to the audit trail.
    /// Returns nothing.
    private func export(csv: Bool, records: [VitalRecord]) {
        do {
            let url = csv
                ? try ExportService.csvFile(for: records)
                : try ExportService.pdfFile(patient: patient, records: records)
            AuditLogger(context: context).record(csv ? "export.csv" : "export.pdf", detail: patient.id.uuidString)
            shareItem = ShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
