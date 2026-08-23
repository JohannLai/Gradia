import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedTab: Int
    @State private var entry: QuickEntry?
    @State private var showSchedule = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    cycleHeader
                    workoutHero
                    quickActions
                    healthOverview
                    coachCard
                    weeklyCard
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.bottom, 34)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("今天")
            .sheet(item: $entry) { selected in
                switch selected {
                case .weight:
                    MetricEntryView(mode: .weight)
                case .waist:
                    MetricEntryView(mode: .waist)
                case .meal:
                    MealCaptureView()
                }
            }
            .sheet(isPresented: $showSchedule) {
                RescheduleView()
            }
        }
    }

    private var cycleHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("12 周身体重组")
                    .font(.subheadline.weight(.semibold))
                Text("第 \(store.currentWeek) 周 · 腰腹下降，力量稳定")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(store.currentWeek) / 12")
                .font(.caption.weight(.bold).monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .foregroundStyle(.tint)
        }
    }

    private var workoutHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("下一次训练")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(store.schedule.nextPlanDay.rawValue) 日")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text(store.schedule.nextPlanDay.focus)
                        .font(.headline)
                }
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                    .frame(width: 62, height: 62)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
            }

            Label(store.schedule.plannedDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute()), systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    store.startWorkout(quickMode: false)
                    selectedTab = 1
                } label: {
                    Label("开始训练", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("改期") { showSchedule = true }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .contentCard()
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速记录")
                .font(.headline)
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    quickButton("晨重", icon: "scalemass.fill", color: .blue) { entry = .weight }
                    quickButton("饮食", icon: "camera.fill", color: .orange) { entry = .meal }
                    quickButton("腰围", icon: "ruler.fill", color: .purple) { entry = .waist }
                }
            }
        }
    }

    private func quickButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    private var healthOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "身体与恢复", subtitle: "Apple 健康 + 手工记录")
            HStack(spacing: 10) {
                MetricPill(icon: "scalemass", value: weightText, label: "最新体重", tint: .blue)
                MetricPill(icon: "figure.walk", value: stepsText, label: "今日步数", tint: .green)
            }
            HStack(spacing: 10) {
                MetricPill(icon: "bed.double.fill", value: sleepText, label: "昨夜睡眠", tint: .indigo)
                MetricPill(icon: "heart.fill", value: heartText, label: "最近静息心率", tint: .red)
            }
        }
    }

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("今日 Coach", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.tint)
            Text("\(store.schedule.nextPlanDay.rawValue) 日先按目标 RIR 校准重量。推胸动作若左肩深部疼痛达到 3/10 或逐组加重，停止加重并切换无痛角度。")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("腿部主项把恶心控制在 3/10 内，不以高心率或想吐作为训练有效的标准。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .contentCard()
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "本周", subtitle: "保持节奏，不追赶错过的训练")
            HStack {
                Label("训练 \(store.sessionsThisWeek) / 3", systemImage: "checkmark.circle.fill")
                Spacer()
                Text(store.latestWaist.map { String(format: "腰围 %.1f cm", $0) } ?? "腰围未记录")
            }
            .font(.subheadline.weight(.medium))
            ProgressView(value: Double(store.sessionsThisWeek), total: 3)
                .tint(.accentColor)
        }
        .contentCard()
    }

    private var weightText: String {
        store.latestWeight.map { String(format: "%.1f kg", $0) } ?? "—"
    }
    private var stepsText: String {
        store.healthSummary.steps.map { $0.formatted() } ?? "—"
    }
    private var sleepText: String {
        store.healthSummary.sleepHours.map { String(format: "%.1f 小时", $0) } ?? "—"
    }
    private var heartText: String {
        store.healthSummary.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "—"
    }
}

private enum QuickEntry: String, Identifiable {
    case weight, waist, meal
    var id: String { rawValue }
}
