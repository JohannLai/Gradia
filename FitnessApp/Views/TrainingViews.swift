import AVFoundation
import SwiftUI
import UIKit

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
                        let duration = RestTimerTiming.effectiveDuration(restSeconds)
                        restUntil = Date.now.addingTimeInterval(TimeInterval(duration))
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

    @State private var offset: CGFloat = 0
    @State private var dragOrigin: CGFloat?
    private let actionWidth: CGFloat = 64

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                content()
                    .frame(width: geometry.size.width, alignment: .leading)

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
            }
            .offset(x: offset)
            .contentShape(Rectangle())
            .simultaneousGesture(swipeGesture, isEnabled: canDelete)
        }
        .frame(height: 44)
        .clipped()
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let origin = dragOrigin ?? offset
                if dragOrigin == nil { dragOrigin = origin }
                offset = SwipeActionMotion.clampedOffset(
                    origin + value.translation.width,
                    actionWidth: actionWidth
                )
            }
            .onEnded { value in
                defer { dragOrigin = nil }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let target = SwipeActionMotion.targetOffset(
                    currentOffset: offset,
                    translation: value.translation.width,
                    predictedTranslation: value.predictedEndTranslation.width,
                    actionWidth: actionWidth
                )
                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.88, blendDuration: 0.05)) {
                    offset = target
                }
            }
    }
}

enum SwipeActionMotion {
    static func clampedOffset(_ offset: CGFloat, actionWidth: CGFloat) -> CGFloat {
        min(0, max(-actionWidth, offset))
    }

    static func targetOffset(
        currentOffset: CGFloat,
        translation: CGFloat,
        predictedTranslation: CGFloat,
        actionWidth: CGFloat
    ) -> CGFloat {
        let remainingProjection = predictedTranslation - translation
        let projectedOffset = currentOffset + remainingProjection * 0.22
        return projectedOffset < -actionWidth / 2 ? -actionWidth : 0
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
    @State private var remaining = 0
    @State private var lastFeedbackSecond: Int?

    var body: some View {
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
        .task(id: until) {
            lastFeedbackSecond = nil
            RestTimerFeedback.shared.prepare()

            while !Task.isCancelled {
                let nextRemaining = RestTimerTiming.remaining(until: until, now: .now)
                remaining = nextRemaining

                if RestTimerTiming.shouldTick(remaining: nextRemaining, lastTicked: lastFeedbackSecond) {
                    lastFeedbackSecond = nextRemaining
                    RestTimerFeedback.shared.tick()
                }

                if nextRemaining == 0 {
                    RestTimerFeedback.shared.finished()
                    cancel()
                    return
                }

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}

enum RestTimerTiming {
    static func remaining(until: Date, now: Date) -> Int {
        max(0, Int(ceil(until.timeIntervalSince(now))))
    }

    static func shouldTick(remaining: Int, lastTicked: Int?) -> Bool {
        (1...10).contains(remaining) && lastTicked != remaining
    }

    static func effectiveDuration(_ duration: Int) -> Int {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--rest-timer-12-seconds") { return 12 }
        #endif
        return duration
    }
}

@MainActor
private final class RestTimerFeedback {
    static let shared = RestTimerFeedback()

    private let tickGenerator = UIImpactFeedbackGenerator(style: .light)
    private let completionGenerator = UINotificationFeedbackGenerator()
    private var completionPlayer: AVAudioPlayer?

    private init() {}

    func prepare() {
        tickGenerator.prepare()
        completionGenerator.prepare()
        if completionPlayer == nil {
            completionPlayer = try? AVAudioPlayer(data: RestTimerCompletionSound.data())
            completionPlayer?.volume = 0.72
            completionPlayer?.prepareToPlay()
        }
    }

    func tick() {
        tickGenerator.impactOccurred(intensity: 0.55)
        tickGenerator.prepare()
    }

    func finished() {
        completionGenerator.notificationOccurred(.success)
        completionGenerator.prepare()
        completionPlayer?.currentTime = 0
        completionPlayer?.play()
    }
}

enum RestTimerCompletionSound {
    static func data() -> Data {
        let sampleRate: UInt32 = 44_100
        let duration = 0.28
        let sampleCount = Int(Double(sampleRate) * duration)
        let bytesPerSample: UInt16 = 2
        let dataSize = UInt32(sampleCount) * UInt32(bytesPerSample)

        var data = Data()
        func appendASCII(_ value: String) { data.append(contentsOf: value.utf8) }
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }

        appendASCII("RIFF")
        appendLE(UInt32(36) + dataSize)
        appendASCII("WAVEfmt ")
        appendLE(UInt32(16))
        appendLE(UInt16(1))
        appendLE(UInt16(1))
        appendLE(sampleRate)
        appendLE(sampleRate * UInt32(bytesPerSample))
        appendLE(bytesPerSample)
        appendLE(UInt16(16))
        appendASCII("data")
        appendLE(dataSize)

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let envelope = exp(-time * 15)
            let tone = sin(2 * Double.pi * 1_760 * time) * 0.68
                + sin(2 * Double.pi * 2_640 * time) * 0.32
            let sample = Int16(max(-1, min(1, tone * envelope * 0.58)) * Double(Int16.max))
            appendLE(sample)
        }

        return data
    }
}

private struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: WorkoutSession

    @State private var celebrationStartedAt = Date.distantPast
    @State private var sealRevealed = false
    @State private var detailsRevealed = false
    @State private var showingShareComposer = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if !reduceMotion, celebrationStartedAt != .distantPast {
                    CelebrationConfettiLayer(startedAt: celebrationStartedAt)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    CelebrationSeal(isRevealed: sealRevealed, reduceMotion: reduceMotion)
                        .padding(.bottom, 26)

                    VStack(spacing: 9) {
                        Text("训练完成")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(2.2)
                        Text("漂亮收官")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("今天的每一组，都算数。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(detailsRevealed ? 1 : 0)
                    .offset(y: detailsRevealed ? 0 : 16)

                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            MetricPill(icon: "clock", value: "\(session.durationMinutes) 分钟", label: "总时长")
                            MetricPill(icon: "dumbbell", value: "\(session.completedSetCount) 组", label: "工作组")
                        }
                        MetricPill(
                            icon: "scalemass",
                            value: String(format: "%.0f kg", session.totalVolume),
                            label: "记录总容量"
                        )
                    }
                    .padding(.top, 28)
                    .opacity(detailsRevealed ? 1 : 0)
                    .offset(y: detailsRevealed ? 0 : 22)

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.forward")
                        Text("下一次：\(session.planDay.next.rawValue) 日 · \(session.planDay.next.focus)")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                    .opacity(detailsRevealed ? 1 : 0)

                    Spacer(minLength: 24)

                    VStack(spacing: 10) {
                        Button {
                            showingShareComposer = true
                        } label: {
                            Label("分享这次训练", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(AppTheme.onAccent)
                        .controlSize(.large)
                        .accessibilityHint("拍摄或选择照片并合成训练数据")

                        Button("完成") { dismiss() }
                            .buttonStyle(.bordered)
                            .tint(.primary)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .accessibilityHint("关闭训练总结")
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
        .fullScreenCover(isPresented: $showingShareComposer) {
            WorkoutShareView(session: session)
        }
        .onAppear(perform: beginCelebration)
    }

    private func beginCelebration() {
        guard celebrationStartedAt == .distantPast else { return }
        celebrationStartedAt = .now
        CelebrationFeedback.play()

        guard !reduceMotion else {
            sealRevealed = true
            detailsRevealed = true
            return
        }

        withAnimation(.spring(duration: 0.78, bounce: 0.38)) {
            sealRevealed = true
        }
        withAnimation(.easeOut(duration: 0.62).delay(0.28)) {
            detailsRevealed = true
        }
    }
}

private struct CelebrationSeal: View {
    let isRevealed: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(index.isMultiple(of: 2) ? 0.26 : 0.12))
                    .frame(width: index.isMultiple(of: 2) ? 3 : 2, height: index.isMultiple(of: 2) ? 22 : 13)
                    .offset(y: -76)
                    .rotationEffect(.degrees(Double(index) * 22.5))
                    .scaleEffect(isRevealed ? 1 : 0.18, anchor: .bottom)
                    .opacity(isRevealed ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.35).delay(Double(index) * 0.012),
                        value: isRevealed
                    )
            }

            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                .frame(width: 132, height: 132)
                .scaleEffect(isRevealed ? 1 : 0.45)

            Circle()
                .fill(Color.primary)
                .frame(width: 94, height: 94)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 39, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                }
                .shadow(color: Color.primary.opacity(0.18), radius: 28, y: 12)
                .scaleEffect(isRevealed ? 1 : 0.12)
                .rotationEffect(.degrees(isRevealed ? 0 : -18))
        }
        .frame(width: 180, height: 180)
        .opacity(isRevealed ? 1 : 0)
        .accessibilityHidden(true)
    }
}

private struct CelebrationConfettiLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    let startedAt: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                guard elapsed >= 0, elapsed < 4.2 else { return }

                for particle in CelebrationParticle.burst {
                    let time = elapsed - particle.delay
                    guard time >= 0, time < particle.lifetime else { continue }

                    let progress = time / particle.lifetime
                    let x = size.width * (0.5 + (particle.origin - 0.5) * 0.16)
                        + particle.horizontalVelocity * time
                    let y = size.height * 0.18
                        + particle.upwardVelocity * time
                        + 0.5 * 420 * time * time
                    let fade = min(1, time * 7) * max(0, 1 - pow(progress, 5))

                    var particleContext = context
                    particleContext.opacity = fade
                    particleContext.translateBy(x: x, y: y)
                    particleContext.rotate(by: .radians(particle.phase + particle.spin * time))

                    let width = particle.size * (particle.kind == 0 ? 0.42 : 1)
                    let rect = CGRect(
                        x: -width / 2,
                        y: -particle.size / 2,
                        width: width,
                        height: particle.size
                    )
                    let path: Path
                    if particle.kind == 2 {
                        path = Path(ellipseIn: rect)
                    } else {
                        path = Path(roundedRect: rect, cornerRadius: min(2.5, width / 2))
                    }
                    particleContext.fill(path, with: .color(color(for: particle.tone)))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func color(for tone: Int) -> Color {
        if colorScheme == .dark {
            return [Color.white, Color(white: 0.72), Color(white: 0.42)][tone]
        }
        return [Color.black, Color(white: 0.28), Color(white: 0.62)][tone]
    }
}

private struct CelebrationParticle: Identifiable {
    let id: Int
    let origin: Double
    let horizontalVelocity: Double
    let upwardVelocity: Double
    let delay: Double
    let lifetime: Double
    let spin: Double
    let phase: Double
    let size: Double
    let kind: Int
    let tone: Int

    static let burst: [CelebrationParticle] = (0..<150).map { index in
        CelebrationParticle(
            id: index,
            origin: unit(index * 11 + 1),
            horizontalVelocity: (unit(index * 11 + 2) - 0.5) * 390,
            upwardVelocity: -120 - unit(index * 11 + 3) * 310,
            delay: unit(index * 11 + 4) * 0.52,
            lifetime: 2.35 + unit(index * 11 + 5) * 1.15,
            spin: (unit(index * 11 + 6) - 0.5) * 13,
            phase: unit(index * 11 + 7) * Double.pi,
            size: 7 + unit(index * 11 + 8) * 10,
            kind: index % 3,
            tone: index % 3
        )
    }

    private static func unit(_ value: Int) -> Double {
        let raw = sin(Double(value) * 12.9898) * 43_758.5453
        return raw - floor(raw)
    }
}

@MainActor
private enum CelebrationFeedback {
    static func play() {
        let success = UINotificationFeedbackGenerator()
        success.prepare()
        success.notificationOccurred(.success)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))
            let firstImpact = UIImpactFeedbackGenerator(style: .rigid)
            firstImpact.prepare()
            firstImpact.impactOccurred(intensity: 0.82)

            try? await Task.sleep(for: .milliseconds(150))
            let secondImpact = UIImpactFeedbackGenerator(style: .light)
            secondImpact.prepare()
            secondImpact.impactOccurred(intensity: 0.58)
        }
    }
}
