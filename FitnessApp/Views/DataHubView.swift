import Charts
import SwiftUI

struct DataHubView: View {
    @State private var mode: DataMode = .history

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("数据页面", selection: $mode) {
                    ForEach(DataMode.allCases) { item in Text(item.rawValue).tag(item) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, 10)

                switch mode {
                case .history: HistoryView()
                case .statistics: StatisticsView()
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("数据")
        }
    }
}

private enum DataMode: String, CaseIterable, Identifiable {
    case history = "历史"
    case statistics = "统计"
    var id: String { rawValue }
}

private struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var displayedMonth = Date.now
    @State private var selectedSession: WorkoutSession?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                monthNavigation
                calendarCard
                if store.sessions.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.plus", title: "还没有训练历史",
                        detail: "完成第一次训练后，这里会显示 A/B/C、训练容量和单次复盘。"
                    )
                    .contentCard()
                } else {
                    recentSessions
                }
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 34)
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
    }

    private var monthNavigation: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .frame(width: 44, height: 44)
            Spacer()
            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.title3.weight(.semibold))
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .frame(width: 44, height: 44)
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 11) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(calendarDays) { value in
                    if let date = value.date {
                        CalendarDayCell(date: date, session: session(on: date)) {
                            selectedSession = session(on: date)
                        }
                    } else {
                        Color.clear.frame(height: 62)
                    }
                }
            }
        }
        .contentCard()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近训练")
            ForEach(store.sessions.prefix(8)) { session in
                Button { selectedSession = session } label: {
                    HStack {
                        Text(session.planDay.rawValue)
                            .font(.headline)
                            .foregroundStyle(AppTheme.onAccent)
                            .frame(width: 38, height: 38)
                            .background(Color.primary, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(session.planDay.rawValue) 日 · \(session.planDay.focus)")
                                .font(.subheadline.weight(.semibold))
                            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(session.totalVolume, specifier: "%.0f") kg")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text("\(session.durationMinutes) 分钟")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contentCard()
    }

    private var calendarDays: [CalendarValue] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let mondayBasedOffset = (firstWeekday + 5) % 7
        var values = Array(repeating: CalendarValue(date: nil), count: mondayBasedOffset)
        values += range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start).map { CalendarValue(date: $0) }
        }
        return values
    }

    private func session(on date: Date) -> WorkoutSession? {
        store.sessions.first { $0.date.isSameDay(as: date) }
    }

    private func shiftMonth(_ value: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }
}

private struct CalendarValue: Identifiable {
    let id = UUID()
    let date: Date?
}

private struct CalendarDayCell: View {
    let date: Date
    let session: WorkoutSession?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption.weight(date.isSameDay(as: .now) ? .bold : .regular))
                    .foregroundStyle(.primary)
                if let session {
                    Text("\(session.totalVolume, specifier: "%.0f")")
                        .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 3))
                    Text("\(session.planDay.rawValue) · \(session.completedSetCount)组")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 3))
                } else {
                    Spacer(minLength: 25)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62, alignment: .top)
        }
        .buttonStyle(.plain)
        .disabled(session == nil)
        .accessibilityLabel(Text(session.map { "\(date.formatted(date: .abbreviated, time: .omitted))，\($0.planDay.rawValue) 日，容量 \(String(format: "%.0f", $0.totalVolume)) 公斤" } ?? date.formatted(date: .abbreviated, time: .omitted)))
    }
}

private struct SessionDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @State private var showingShareComposer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        MetricPill(icon: "scalemass", value: String(format: "%.0f kg", session.totalVolume), label: "总容量")
                        MetricPill(icon: "clock.fill", value: "\(session.durationMinutes) 分", label: "时长")
                        MetricPill(icon: "square.stack.3d.up.fill", value: "\(session.completedSetCount)", label: "工作组")
                    }
                    Button {
                        showingShareComposer = true
                    } label: {
                        Label("分享这次训练", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(AppTheme.onAccent)
                    .controlSize(.large)
                    .accessibilityHint("拍摄或选择照片并合成这次训练的数据")
                    symptomRow
                    exerciseList
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("\(session.planDay.rawValue) 日训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .fullScreenCover(isPresented: $showingShareComposer) {
            WorkoutShareView(session: session)
        }
    }

    private var symptomRow: some View {
        HStack {
            Label("肩 \(session.shoulderPain)", systemImage: "figure.arms.open")
            Spacer()
            Label("恶心 \(session.nausea)", systemImage: "waveform.path.ecg")
            Spacer()
            Label("下背 \(session.lowerBackDiscomfort)", systemImage: "figure.flexibility")
        }
        .font(.subheadline.weight(.medium))
        .contentCard()
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "动作记录")
            ForEach(groupedSets, id: \.0) { exerciseID, sets in
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.workoutPlan.first(where: { $0.id == exerciseID })?.name ?? exerciseID)
                        .font(.headline)
                    HStack(spacing: 8) {
                        ForEach(sets) { set in
                            VStack(spacing: 3) {
                                Text(set.weightKG.map { String(format: "%.1f", $0) } ?? "—")
                                    .font(.subheadline.bold().monospacedDigit())
                                Text("\(set.reps) 次")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .contentCard()
    }

    private var groupedSets: [(String, [WorkoutSetRecord])] {
        Dictionary(grouping: session.sets.filter(\.completed), by: \.exerciseID)
            .sorted { $0.key < $1.key }
    }
}

private struct StatisticsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var period: StatisticsPeriod = .week
    @State private var selectedMuscle: MuscleGroup?

    private var contributions: [MuscleContribution] { store.muscleContributions(period: period) }
    private var previousContributions: [MuscleContribution] {
        store.muscleContributions(period: period, referenceDate: previousReferenceDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("统计周期", selection: $period) {
                    ForEach(StatisticsPeriod.allCases) { item in Text(item.rawValue).tag(item) }
                }
                .pickerStyle(.segmented)

                muscleOverview
                trainingSummary
                groupComparison
                bodyTrend
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 34)
        }
        .sheet(item: $selectedMuscle) { muscle in
            MuscleDetailView(
                muscle: muscle,
                contribution: contributions.first(where: { $0.id == muscle }),
                previousContribution: previousContributions.first(where: { $0.id == muscle }),
                period: period
            )
        }
    }

    private var muscleOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "部位概览", subtitle: "主肌群每组 1 · 次肌群每组 0.5 · 月/年显示周均")
            MuscleMapView(contributions: contributions, period: period, selectedMuscle: $selectedMuscle)
            HStack(spacing: 5) {
                Text("少")
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3).fill(AppTheme.muscleScale[level]).frame(width: 28, height: 8)
                }
                Text("多")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .contentCard()
    }

    private var trainingSummary: some View {
        let periodSessions = store.sessions(in: period)
        let totalSets = periodSessions.reduce(0) { $0 + $1.completedSetCount }
        let duration = periodSessions.reduce(0) { $0 + $1.durationMinutes }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "训练总览", subtitle: period.rawValue + "统计")
            HStack(spacing: 10) {
                MetricPill(icon: "calendar", value: "\(periodSessions.count)", label: "训练次数")
                MetricPill(icon: "square.stack.3d.up", value: "\(totalSets)", label: "工作组")
                MetricPill(icon: "clock", value: "\(duration)", label: "分钟")
            }
        }
        .contentCard()
    }

    private var groupComparison: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "肌群组数", subtitle: "点按可查看贡献动作")
            let sorted = contributions.filter { $0.weightedSets > 0 }.sorted { $0.weightedSets > $1.weightedSets }
            if sorted.isEmpty {
                EmptyStateView(icon: "figure.strengthtraining.traditional", title: "等待第一笔训练", detail: "完成工作组后，人体图和肌群对比会自动生成。")
            } else {
                ForEach(sorted) { contribution in
                    Button { selectedMuscle = contribution.id } label: {
                        HStack {
                            Text(contribution.id.displayName)
                                .font(.subheadline.weight(.medium))
                                .frame(width: 105, alignment: .leading)
                            ProgressView(value: contribution.weightedSets, total: max(sorted.first?.weightedSets ?? 1, 1))
                                .tint(.primary)
                            Text(contribution.weightedSets, format: .number.precision(.fractionLength(1)))
                                .font(.subheadline.bold().monospacedDigit())
                                .frame(width: 38, alignment: .trailing)
                            Text(deltaText(for: contribution))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentCard()
    }

    private var previousReferenceDate: Date {
        let component: Calendar.Component
        switch period {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        let start = Calendar.current.dateInterval(of: component, for: .now)?.start ?? .now
        return start.addingTimeInterval(-1)
    }

    private func deltaValue(for contribution: MuscleContribution) -> Double {
        contribution.weightedSets - (previousContributions.first(where: { $0.id == contribution.id })?.weightedSets ?? 0)
    }

    private func deltaText(for contribution: MuscleContribution) -> String {
        let value = deltaValue(for: contribution)
        return String(format: "%@%.1f", value >= 0 ? "+" : "", value)
    }

    private var bodyTrend: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "身体趋势", subtitle: "体重原始值 · 7 日均值将在连续记录后显示")
            if weightMetrics.count < 2 {
                EmptyStateView(icon: "chart.line.uptrend.xyaxis", title: "数据还不够", detail: "已有 InBody 基线；继续记录晨重后会形成趋势。")
            } else {
                Chart(weightMetrics) { metric in
                    if let weight = metric.weightKG {
                        LineMark(x: .value("日期", metric.date), y: .value("体重", weight))
                            .foregroundStyle(Color.primary.gradient)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("日期", metric.date), y: .value("体重", weight))
                            .foregroundStyle(.primary)
                    }
                }
                .chartYAxisLabel("kg")
                .frame(height: 190)
                .accessibilityLabel("体重趋势图")
            }
        }
        .contentCard()
    }

    private var weightMetrics: [BodyMetric] {
        store.bodyMetrics
            .filter { $0.weightKG != nil && $0.source != .healthKit }
            .sorted { $0.date < $1.date }
    }
}

private struct MuscleDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let muscle: MuscleGroup
    let contribution: MuscleContribution?
    let previousContribution: MuscleContribution?
    let period: StatisticsPeriod

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("加权有效组") {
                        Text(contribution?.weightedSets ?? 0, format: .number.precision(.fractionLength(1)))
                            .font(.title2.bold().monospacedDigit())
                    }
                    LabeledContent("较上期") {
                        Text(delta, format: .number.sign(strategy: .always()).precision(.fractionLength(1)))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("主肌群每个合格工作组计 1，次肌群计 0.5。\(period == .week ? "当前周期组数" : "月/年均换算为周平均")；颜色表示训练覆盖，不是医学或最佳训练量判断。")
                }

                Section("贡献动作") {
                    if let items = contribution?.exerciseBreakdown, !items.isEmpty {
                        ForEach(items.sorted(by: { $0.value > $1.value }), id: \.key) { exerciseID, value in
                            LabeledContent(store.workoutPlan.first(where: { $0.id == exerciseID })?.name ?? exerciseID) {
                                Text(value, format: .number.precision(.fractionLength(1)))
                            }
                        }
                    } else {
                        Text("当前周期暂无记录").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(muscle.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var delta: Double {
        (contribution?.weightedSets ?? 0) - (previousContribution?.weightedSets ?? 0)
    }
}
