import SwiftUI

struct TrainingHomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            Group {
                if let draft = store.activeDraft {
                    ActiveWorkoutView(draft: draft)
                } else {
                    workoutOverview
                }
            }
            .navigationTitle(store.activeDraft == nil ? "训练" : "")
            .navigationBarTitleDisplayMode(store.activeDraft == nil ? .large : .inline)
        }
    }

    private var workoutOverview: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("下一次")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(store.schedule.nextPlanDay.rawValue) 日")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Spacer()
                        Text("约 60 分钟")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(store.schedule.nextPlanDay.focus)
                        .font(.title3.weight(.semibold))
                    Button {
                        store.startWorkout(quickMode: false)
                    } label: {
                        Label("开始完整训练", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(AppTheme.onAccent)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                }
                .contentCard()

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "今日计划", subtitle: "来自真实 Google Sheet")
                    ForEach(store.nextWorkoutItems) { item in
                        PlanItemRow(item: item, configuration: store.exerciseConfigurations[item.id])
                        if item.id != store.nextWorkoutItems.last?.id { Divider() }
                    }
                }
                .contentCard()
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 36)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct PlanItemRow: View {
    let item: WorkoutPlanItem
    let configuration: ExerciseConfiguration?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.orderLabel)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(item.kind == .strength ? Color.primary : .secondary)
                .frame(width: 34, height: 34)
                .background((item.kind == .strength ? Color.primary : Color.secondary).opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Text(targetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.equipment)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            Spacer()
            ExerciseGuideButton(item: item, configuration: configuration, compact: true)
        }
        .padding(.vertical, 5)
    }

    private var targetText: String {
        if let sets = item.sets, let min = item.repMin, let max = item.repMax {
            return String(
                format: "%d 组 × %d–%d 次 · RIR %.0f–%.0f",
                sets, min, max, item.targetRIRMin ?? 0, item.targetRIRMax ?? 0
            )
        }
        return item.durationText ?? item.kind.rawValue
    }
}

struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthKit: HealthKitService
    @ObservedObject var draft: ActiveWorkoutDraft
    @State private var restUntil: Date?
    @State private var showFinish = false
    @State private var showAbandon = false
    @State private var completedSession: WorkoutSession?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                workoutHeader
                warmupReminder
                ForEach(draft.exercises) { exercise in
                    ExerciseInputCard(
                        exercise: exercise,
                        lastSets: store.lastSets(for: exercise.item.id),
                        configuration: store.exerciseConfigurations[exercise.item.id]
                    ) { restSeconds in
                        restUntil = Date.now.addingTimeInterval(TimeInterval(restSeconds))
                    } onAddSet: {
                        draft.addSet(to: exercise.id)
                        store.persistActiveDraft()
                    } onDeleteSet: { setID in
                        draft.removeAddedSet(setID, from: exercise.id)
                        store.persistActiveDraft()
                    }
                }
                symptomSummary
                finishButton
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, restUntil == nil ? 38 : 110)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            if let restUntil {
                RestTimerBar(until: restUntil) { self.restUntil = nil }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .cancel) { showAbandon = true } label: { Image(systemName: "xmark") }
            }
            ToolbarItem(placement: .principal) {
                Text("\(draft.planDay.rawValue) 日")
                    .font(.headline)
            }
        }
        .sheet(isPresented: $showAbandon) {
            AbandonWorkoutSheet {
                showAbandon = false
                store.abandonWorkout()
            }
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFinish) {
            if let session = completedSession {
                WorkoutSummaryView(session: session)
            }
        }
        .task(id: draft.id) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                store.persistActiveDraft()
            }
        }
        .onDisappear { store.persistActiveDraft() }
    }

    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.planDay.focus)
                        .font(.title2.weight(.bold))
                    Text("\(draft.completedSetCount) / \(draft.totalSetCount) 个工作组")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.16), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: draft.totalSetCount == 0 ? 0 : Double(draft.completedSetCount) / Double(draft.totalSetCount))
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(draft.completedSetCount)")
                        .font(.headline.monospacedDigit())
                }
                .frame(width: 62, height: 62)
            }
        }
        .padding(.top, 6)
    }

    private var warmupReminder: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flame.fill").foregroundStyle(.primary)
            Text(store.nextWorkoutItems.first(where: { $0.kind == .warmup })?.notes ?? "先完成关节和专项热身。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .contentCard()
    }

    private var symptomSummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: "身体反应", subtitle: "异常评分会阻止自动加重")
            SymptomSlider(title: "左肩疼痛", value: $draft.shoulderPain, tint: .primary)
            SymptomSlider(title: "恶心", value: $draft.nausea, tint: .primary)
            SymptomSlider(title: "下背不适", value: $draft.lowerBackDiscomfort, tint: .primary)
            TextField("整场备注（可选）", text: $draft.note, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        }
        .contentCard()
    }

    private var finishButton: some View {
        Button {
            guard let session = store.completeWorkout() else { return }
            completedSession = session
            showFinish = true
            Task {
                if let workoutID = try? await healthKit.saveWorkout(session) {
                    store.linkHealthKitWorkout(sessionID: session.id, workoutID: workoutID)
                }
            }
        } label: {
            Label("完成训练", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
                .foregroundStyle(AppTheme.onAccent)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(draft.completedSetCount == 0)
    }
}

private struct ExerciseInputCard: View {
    @ObservedObject var exercise: ExerciseDraft
    let lastSets: [WorkoutSetRecord]
    let configuration: ExerciseConfiguration?
    let onSetCompleted: (Int) -> Void
    let onAddSet: () -> Void
    let onDeleteSet: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ExerciseGuideHeader(item: exercise.item, configuration: configuration)

            VStack(alignment: .leading, spacing: 4) {
                Text(lastText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(targetText)
                    .font(.footnote.weight(.semibold))
            }

            HStack {
                Text("组")
                Spacer()
                Text("重量 kg").frame(width: 82)
                Text("次数").frame(width: 62)
                Text("RIR").frame(width: 55)
                Text("").frame(width: 34)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SwipeToDeleteSetRow(
                    canDelete: index >= (exercise.item.sets ?? 0),
                    onDelete: { onDeleteSet(set.id) }
                ) {
                    SetInputRow(index: index, set: set) {
                        if index > 0, set.weightText.isEmpty { set.weightText = exercise.sets[index - 1].weightText }
                    } onComplete: {
                        let seconds = exercise.item.restSeconds?.lowerBound ?? 90
                        onSetCompleted(seconds)
                    }
                }
            }

            Button(action: onAddSet) {
                Label("增加一组", systemImage: "plus")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .trailing)

            Text(exercise.item.notes)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .contentCard()
    }

    private var lastText: String {
        guard !lastSets.isEmpty else { return "上次：暂无记录" }
        let weight = lastSets.compactMap(\.weightKG).last.map { String(format: "%.1f kg", $0) } ?? "自重"
        let reps = lastSets.map { String($0.reps) }.joined(separator: " / ")
        return "上次：\(weight) · \(reps)"
    }

    private var targetText: String {
        let recommendation = ProgressionEngine.recommend(
            item: exercise.item, previousSets: lastSets, shoulderPain: 0, nausea: 0,
            lowerBackDiscomfort: 0, configuration: configuration
        )
        return "今日目标：\(recommendation.title)"
    }
}

private struct SwipeToDeleteSetRow<Content: View>: View {
    let canDelete: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isRevealed = false
    @GestureState private var dragTranslation: CGFloat = 0
    private let actionWidth: CGFloat = 64

    var body: some View {
        ZStack(alignment: .trailing) {
            if canDelete {
                Button(role: .destructive) {
                    withAnimation(.snappy) { onDelete() }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: actionWidth, height: 44)
                        .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除这一组")
            }

            content()
                .offset(x: horizontalOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(swipeGesture, isEnabled: canDelete)
        }
        .clipped()
    }

    private var horizontalOffset: CGFloat {
        let startingOffset = isRevealed ? -actionWidth : 0
        return min(0, max(-actionWidth, startingOffset + dragTranslation))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.predictedEndTranslation.width < -140 {
                    withAnimation(.snappy) { onDelete() }
                } else {
                    let projectedOffset = (isRevealed ? -actionWidth : 0) + value.predictedEndTranslation.width
                    withAnimation(.snappy) { isRevealed = projectedOffset < -actionWidth / 2 }
                }
            }
    }
}

private struct AbandonWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAbandon: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 7) {
                Text("结束并丢弃这次训练？")
                    .font(.headline)
                Text("已输入的训练数据会被移除。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive, action: onAbandon) {
                Text("丢弃训练")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)

            Button("继续训练") { dismiss() }
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

private struct SetInputRow: View {
    let index: Int
    @ObservedObject var set: SetDraft
    let onFocus: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.headline.monospacedDigit())
                .frame(width: 24)
            Spacer()
            TextField("—", text: $set.weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 82, height: 44)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                .onTapGesture(perform: onFocus)
            TextField("—", text: $set.repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 62, height: 44)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            TextField("—", text: $set.rirText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 55, height: 44)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            Button {
                set.completed.toggle()
                if set.completed { onComplete() }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.completed ? Color.primary : .secondary)
                    .frame(width: 34, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(set.reps == 0)
        }
        .font(.headline.monospacedDigit())
        .opacity(set.completed ? 0.72 : 1)
    }
}

private struct SymptomSlider: View {
    let title: String
    @Binding var value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(value) / 10")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(value >= 3 ? tint : .secondary)
            }
            Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }), in: 0...10, step: 1)
                .tint(value >= 3 ? tint : .accentColor)
        }
    }
}

private struct RestTimerBar: View {
    let until: Date
    let cancel: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(until.timeIntervalSince(context.date)))
            HStack(spacing: 12) {
                Image(systemName: "timer")
                VStack(alignment: .leading, spacing: 1) {
                    Text("组间休息").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                        .font(.title3.bold().monospacedDigit())
                }
                Spacer()
                Button("跳过", action: cancel)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 18)
            .frame(height: 68)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 25))
        }
    }
}

private struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 76, height: 76)
                    .background(Color.primary, in: Circle())
                VStack(spacing: 7) {
                    Text("训练完成")
                        .font(.largeTitle.bold())
                    Text("下一次：\(session.planDay.next.rawValue) 日 · \(session.planDay.next.focus)")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    MetricPill(icon: "clock", value: "\(session.durationMinutes) 分钟", label: "总时长")
                    MetricPill(icon: "dumbbell", value: "\(session.completedSetCount) 组", label: "工作组")
                }
                MetricPill(icon: "scalemass", value: String(format: "%.0f kg", session.totalVolume), label: "记录总容量")
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(AppTheme.onAccent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
    }
}
