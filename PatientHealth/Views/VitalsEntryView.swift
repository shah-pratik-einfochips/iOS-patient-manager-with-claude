import SwiftUI
import SwiftData

// MARK: - VitalsEntryView

struct VitalsEntryView: View {
    @Environment(\.modelContext) private var context
    let patient: Patient
    var onSaved: () -> Void = {}
    @State private var vm = VitalsEntryViewModel()

    var body: some View {
        Form {
            Section("Measurement") {
                DatePicker("Date & time", selection: $vm.recordedAt, in: ...Date())
                errorLine(vm.dateError)
            }
            Section("Blood Pressure") {
                numberField("Systolic (mmHg)", text: $vm.systolic, error: vm.systolicError, abnormal: vm.isAbnormal(.systolic))
                numberField("Diastolic (mmHg)", text: $vm.diastolic, error: vm.diastolicError, abnormal: vm.isAbnormal(.diastolic))
                errorLine(vm.pairError)
                LabeledContent("MAP (auto)") {
                    HStack {
                        Text(vm.mapValue.map { "\($0.oneDecimal) mmHg" } ?? "—")
                        if vm.isAbnormal(.map) { flag }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Section("Vitals") {
                numberField("Heart rate (bpm)", text: $vm.heartRate, error: vm.heartRateError, abnormal: vm.isAbnormal(.heartRate))
                numberField("Respiratory rate (breaths/min)", text: $vm.respiratoryRate, error: vm.respiratoryError, abnormal: vm.isAbnormal(.respiratoryRate))
                numberField("SpO₂ (%)", text: $vm.spo2, error: vm.spo2Error, abnormal: vm.isAbnormal(.spo2))
            }
            Section("Body Measurements") {
                Picker("Height unit", selection: $vm.heightUnit) { ForEach(HeightUnit.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                if vm.heightUnit == .cm {
                    numberField("Height (cm)", text: $vm.heightCm, error: vm.heightError, abnormal: false)
                } else {
                    HStack {
                        numberField("Feet", text: $vm.heightFeet, error: vm.heightError, abnormal: false)
                        numberField("Inches", text: $vm.heightInches, error: nil, abnormal: false)
                    }
                }
                Picker("Weight unit", selection: $vm.weightUnit) { ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                numberField("Weight (\(vm.weightUnit.rawValue))", text: $vm.weight, error: vm.weightError, abnormal: false)
                Picker("Temperature unit", selection: $vm.temperatureUnit) { ForEach(TemperatureUnit.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                numberField("Temperature (\(vm.temperatureUnit.rawValue))", text: $vm.temperature, error: vm.temperatureError,
                            abnormal: vm.isAbnormal(.temperature))
            }
            Section("Pain & Symptoms") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Pain level")
                        Spacer()
                        Text(vm.painEntered ? "\(Int(vm.painLevel)) / 10" : "Not set").foregroundStyle(.secondary)
                        if vm.isAbnormal(.painLevel) { flag }
                    }
                    Slider(value: Binding(get: { vm.painLevel }, set: { vm.painLevel = $0; vm.painEntered = true }), in: 0...10, step: 1)
                        .accessibilityLabel("Pain level")
                        .accessibilityValue("\(Int(vm.painLevel)) out of 10")
                }
                TextField("Symptoms", text: $vm.symptoms, axis: .vertical).lineLimit(2...5)
            }
            Section {
                Button("Save Vitals", action: save).disabled(!vm.canSave)
            }
        }
    }

    private var flag: some View {
        Label("Abnormal", systemImage: "exclamationmark.triangle.fill")
            .labelStyle(.iconOnly).foregroundStyle(.red)
            .accessibilityLabel("Abnormal value")
    }

    @ViewBuilder private func errorLine(_ e: String?) -> some View {
        if let e { Text(e).font(.footnote).foregroundStyle(.red) }
    }

    private func numberField(_ title: String, text: Binding<String>, error: String?, abnormal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                TextField(title, text: text).keyboardType(.decimalPad)
                    .foregroundStyle(abnormal ? .red : .primary)
                if abnormal { flag }
            }
            errorLine(error)
            if abnormal && error == nil { Text("Outside normal range").font(.footnote).foregroundStyle(.secondary) }
        }
    }

    /// Saves the vitals record to the patient.
    /// Logs an audit entry and resets the form.
    /// Returns nothing.
    private func save() {
        let record = vm.makeRecord()
        record.patient = patient
        context.insert(record)
        try? context.save()
        AuditLogger(context: context).record("vitals.create", detail: patient.id.uuidString)
        vm = VitalsEntryViewModel()
        onSaved()
    }
}
