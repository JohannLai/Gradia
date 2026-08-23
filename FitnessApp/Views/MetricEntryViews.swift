import SwiftUI

enum MetricEntryMode {
    case weight
    case waist
}

struct MetricEntryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let mode: MetricEntryMode
    @State private var value = ""
    @State private var sleep = ""
    @State private var steps = ""
    @State private var fatigue = 3
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .lastTextBaseline) {
                        TextField(mode == .weight ? "74.9" : "84.0", text: $value)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 42, weight: .semibold, design: .rounded).monospacedDigit())
                        Text(mode == .weight ? "kg" : "cm")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(mode == .weight ? "今日晨重" : "肚脐水平腰围")
                } footer: {
                    if mode == .waist {
                        Text("自然呼气、腹部放松、不吸肚子。尽量在相同时间和条件下测量。")
                    }
                }

                if mode == .weight {
                    Section("可选恢复信息") {
                        TextField("睡眠小时", text: $sleep)
                            .keyboardType(.decimalPad)
                        TextField("步数", text: $steps)
                            .keyboardType(.numberPad)
                        Stepper("主观疲劳：\(fatigue) / 5", value: $fatigue, in: 1...5)
                    }
                }

                Section("备注（可选）") {
                    TextField("例如测量条件或身体感受", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(mode == .weight ? "记录晨重" : "记录腰围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.saveBodyMetric(
                            weightKG: mode == .weight ? Double(value) : nil,
                            waistCM: mode == .waist ? Double(value) : nil,
                            sleepHours: Double(sleep), steps: Int(steps),
                            fatigue: mode == .weight ? fatigue : nil, note: note
                        )
                        dismiss()
                    }
                    .disabled(Double(value) == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct RescheduleView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var confirmAdvance = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.reschedule(to: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
                        dismiss()
                    } label: {
                        Label("改到明天", systemImage: "sunrise.fill")
                    }

                    DatePicker("选择其他日期", selection: $selectedDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    Button("使用所选日期") {
                        store.reschedule(to: selectedDate)
                        dismiss()
                    }
                } header: {
                    Text("\(store.schedule.nextPlanDay.rawValue) 日保持不变")
                } footer: {
                    Text("普通改期不会推进训练序列，后续建议日期会自动顺延。")
                }

                Section {
                    Button("本次直接跳过并推进", role: .destructive) { confirmAdvance = true }
                } footer: {
                    Text("只有这个操作会从 \(store.schedule.nextPlanDay.rawValue) 推进到 \(store.schedule.nextPlanDay.next.rawValue)。")
                }
            }
            .navigationTitle("改期或跳过")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .confirmationDialog("确定跳过并推进？", isPresented: $confirmAdvance, titleVisibility: .visible) {
                Button("跳过并推进", role: .destructive) {
                    store.skipAndAdvance()
                    dismiss()
                }
            } message: {
                Text("这个选择会记录一次明确跳过，并将下一次训练改为 \(store.schedule.nextPlanDay.next.rawValue) 日。")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

