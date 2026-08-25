import AVFoundation
import Foundation
import MuscleMap
import SwiftData
import Testing
import UIKit
@testable import FitnessApp

struct FitnessAppTests {
    @Test("真实计划包含 Google Sheet 的 25 条记录")
    func realPlanCount() {
        #expect(SeedData.plan.count == 25)
        #expect(SeedData.plan.filter { $0.planDay == .a }.count == 8)
        #expect(SeedData.plan.filter { $0.planDay == .b }.count == 8)
        #expect(SeedData.plan.filter { $0.planDay == .c }.count == 9)
    }

    @Test("19 个力量动作都有动作指南")
    func everyStrengthExerciseHasGuide() {
        let strengthItems = SeedData.plan.filter { $0.kind == .strength }
        #expect(strengthItems.count == 19)
        #expect(ExerciseGuideCatalog.all.count == 19)
        for item in strengthItems {
            let guide = ExerciseGuideCatalog.guide(for: item.id)
            #expect(guide != nil)
            #expect(guide?.steps.isEmpty == false)
            #expect(guide?.animationURL.host == "raw.githubusercontent.com")
        }
        #expect(Set(ExerciseGuideCatalog.all.map(\.planItemID)).count == 19)
    }

    @Test("旧 Sheet 仅在九列标题匹配时解析")
    func legacyParser() {
        let rows = [
            ["日别", "顺序", "动作", "使用器械", "组数", "次数/时长", "RIR", "休息", "说明 / 第一周执行"],
            ["A", "1", "杠铃卧推", "卧推架", "3", "6–10", "2", "2–3分钟", "40kg×8×3"]
        ]
        let parsed = LegacyPlanParser.parse(rows: rows)
        #expect(parsed.count == 1)
        #expect(parsed.first?.exercise == "杠铃卧推")
        #expect(LegacyPlanParser.parse(rows: [["错误标题"]]).isEmpty)
    }

    @Test("卧推三组达到上限且症状达标时加重")
    func progressionIncrease() {
        let item = SeedData.plan.first { $0.id == "A-01" }!
        let sets = (1...3).map {
            WorkoutSetRecord(id: UUID(), exerciseID: item.id, setIndex: $0, weightKG: 40, reps: 10, rir: 2, completed: true, stoppedForPain: false, completedAt: .now)
        }
        let result = ProgressionEngine.recommend(
            item: item, previousSets: sets, shoulderPain: 0, nausea: 0,
            lowerBackDiscomfort: 0, configuration: SeedData.configurations[item.id]
        )
        #expect(result.action == .increase)
        #expect(result.suggestedWeight == 42.5)
    }

    @Test("肩痛达到三分时禁止加重")
    func progressionPainHold() {
        let item = SeedData.plan.first { $0.id == "A-01" }!
        let sets = (1...3).map {
            WorkoutSetRecord(id: UUID(), exerciseID: item.id, setIndex: $0, weightKG: 40, reps: 10, rir: 2, completed: true, stoppedForPain: false, completedAt: .now)
        }
        let result = ProgressionEngine.recommend(
            item: item, previousSets: sets, shoulderPain: 3, nausea: 0,
            lowerBackDiscomfort: 0, configuration: SeedData.configurations[item.id]
        )
        #expect(result.action == .safetyHold)
    }

    @Test("肌群统计主肌群一组、次肌群半组")
    func weightedMuscleSets() {
        let set = WorkoutSetRecord(
            id: UUID(), exerciseID: "A-01", setIndex: 1, weightKG: 40,
            reps: 8, rir: 2, completed: true, stoppedForPain: false, completedAt: .now
        )
        let session = WorkoutSession(
            id: UUID(), date: .now, planDay: .a, startedAt: .now,
            endedAt: .now.addingTimeInterval(3600), durationMinutes: 60,
            sets: [set], shoulderPain: 0, nausea: 0, lowerBackDiscomfort: 0,
            note: "", quickMode: false
        )
        let result = MuscleStatsCalculator.calculate(sessions: [session], configurations: SeedData.configurations)
        #expect(result.first { $0.id == .chest }?.weightedSets == 1)
        #expect(result.first { $0.id == .triceps }?.weightedSets == 0.5)
        #expect(result.first { $0.id == .frontDelts }?.weightedSets == 0.5)
    }

    @Test("跳过、疼痛中止和 RIR 超界的组不进入肌群统计")
    func ineligibleSetsAreExcluded() {
        let sets = [
            WorkoutSetRecord(id: UUID(), exerciseID: "A-01", setIndex: 1, weightKG: 40, reps: 8, rir: 2, completed: false, stoppedForPain: false, completedAt: nil),
            WorkoutSetRecord(id: UUID(), exerciseID: "A-01", setIndex: 2, weightKG: 40, reps: 8, rir: 2, completed: true, stoppedForPain: true, completedAt: .now),
            WorkoutSetRecord(id: UUID(), exerciseID: "A-01", setIndex: 3, weightKG: 40, reps: 8, rir: 5, completed: true, stoppedForPain: false, completedAt: .now),
            WorkoutSetRecord(id: UUID(), exerciseID: "A-01", setIndex: 4, weightKG: 40, reps: 8, rir: nil, completed: true, stoppedForPain: false, completedAt: .now)
        ]
        let session = WorkoutSession(
            id: UUID(), date: .now, planDay: .a, startedAt: .now,
            endedAt: .now.addingTimeInterval(3600), durationMinutes: 60,
            sets: sets, shoulderPain: 0, nausea: 0, lowerBackDiscomfort: 0,
            note: "", quickMode: false
        )
        let result = MuscleStatsCalculator.calculate(sessions: [session], configurations: SeedData.configurations)
        #expect(result.first { $0.id == .chest }?.weightedSets == 1)
        #expect(result.first { $0.id == .triceps }?.weightedSets == 0.5)
    }

    @Test("疼痛中止会阻止下一次加重")
    func stoppedForPainBlocksIncrease() {
        let item = SeedData.plan.first { $0.id == "A-01" }!
        var sets = (1...3).map {
            WorkoutSetRecord(id: UUID(), exerciseID: item.id, setIndex: $0, weightKG: 40, reps: 10, rir: 2, completed: true, stoppedForPain: false, completedAt: .now)
        }
        sets[2].stoppedForPain = true
        let result = ProgressionEngine.recommend(
            item: item, previousSets: sets, shoulderPain: 0, nausea: 0,
            lowerBackDiscomfort: 0, configuration: SeedData.configurations[item.id]
        )
        #expect(result.action == .safetyHold)
    }

    @Test("月年肌群组数按周平均换算并使用五级色阶")
    func weeklyNormalizationAndScale() {
        #expect(MuscleStatsCalculator.weeklyNormalized(24, period: .month, dayCount: 28) == 6)
        #expect(MuscleStatsCalculator.weeklyNormalized(52, period: .year, dayCount: 364) == 1)
        #expect(MuscleStatsCalculator.intensityLevel(for: 0) == 0)
        #expect(MuscleStatsCalculator.intensityLevel(for: 2.9) == 1)
        #expect(MuscleStatsCalculator.intensityLevel(for: 5.9) == 2)
        #expect(MuscleStatsCalculator.intensityLevel(for: 8.9) == 3)
        #expect(MuscleStatsCalculator.intensityLevel(for: 9) == 4)
    }

    @Test("改期不推进，完成训练推进")
    func scheduleSequence() {
        let original = ScheduleState(nextPlanDay: .a, plannedDate: .now, status: .planned, updatedAt: .now)
        let rescheduled = ScheduleEngine.reschedule(original, to: .now.addingTimeInterval(86_400))
        #expect(rescheduled.nextPlanDay == .a)
        let advanced = ScheduleEngine.advance(rescheduled, completionDate: rescheduled.plannedDate)
        #expect(advanced.nextPlanDay == .b)
        #expect(Calendar.current.dateComponents([.day], from: rescheduled.plannedDate.startOfDay, to: advanced.plannedDate.startOfDay).day ?? 0 >= 2)
    }

    @Test("15 个业务肌群均可映射到 MuscleMap")
    func allMusclesHaveVisualTargets() {
        for muscle in MuscleGroup.allCases {
            #expect(!MuscleMapAdapter.sdkMuscles(for: muscle).isEmpty)
        }
    }

    @Test("MuscleMap 缺失的背阔和侧束使用稳定兼容映射")
    func muscleMapCompatibilityMapping() {
        #expect(MuscleMapAdapter.sdkMuscles(for: .lats) == [.upperBack])
        #expect(MuscleMapAdapter.appMuscle(for: .upperBack) == .lats)
        #expect(MuscleMapAdapter.sdkMuscles(for: .sideDelts) == [.deltoids])
        #expect(MuscleMapAdapter.appMuscle(for: .deltoids) == .sideDelts)
        #expect(Set(MuscleMapAdapter.sdkMuscles(for: .upperBack)) == Set([.trapezius, .rhomboids]))
    }

    @Test("同一天 HealthKit 刷新只保留一个待同步实体")
    @MainActor
    func healthDailyOutboxCoalescing() throws {
        let container = try ModelContainer(
            for: LocalRecord.self,
            PendingMutation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = AppStore(context: container.mainContext, autoSyncEnabled: false)
        store.importHealthSummary(HealthSummary(steps: 1_000))
        store.importHealthSummary(HealthSummary(steps: 2_000))
        #expect(store.pendingCount == 1)
    }

    @Test("HealthKit 日汇总不会写入或覆盖体重")
    @MainActor
    func healthSummaryDoesNotImportWeight() throws {
        let container = try ModelContainer(
            for: LocalRecord.self,
            PendingMutation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = AppStore(context: container.mainContext, autoSyncEnabled: false)
        store.importHealthSummary(HealthSummary(steps: 3_000, restingHeartRate: 58))
        #expect(store.bodyMetrics.last(where: { $0.source == .healthKit })?.weightKG == nil)
        #expect(store.latestWeight == 74.9)
    }

    @Test("同步退避从两秒指数增长并封顶五分钟")
    func retryBackoff() {
        #expect(SyncRetryPolicy.delay(forRetryCount: 0) == 0)
        #expect(SyncRetryPolicy.delay(forRetryCount: 1) == 2)
        #expect(SyncRetryPolicy.delay(forRetryCount: 4) == 16)
        #expect(SyncRetryPolicy.delay(forRetryCount: 20) == 300)
    }

    @Test("重叠睡眠阶段只计算一次")
    func overlappingSleepIntervalsAreMerged() {
        let start = Date(timeIntervalSince1970: 1_000)
        let intervals = [
            DateInterval(start: start, duration: 3_600),
            DateInterval(start: start.addingTimeInterval(1_800), duration: 3_600),
            DateInterval(start: start.addingTimeInterval(7_200), duration: 1_800)
        ]
        #expect(HealthKitService.mergedDuration(of: intervals) == 7_200)
    }

    @Test("昨夜睡眠窗口不会在晚上截断前半夜")
    func previousNightWindowUsesEveningBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let end = ISO8601DateFormatter().date(from: "2026-08-23T20:30:00+08:00")!
        let expectedStart = ISO8601DateFormatter().date(from: "2026-08-22T16:00:00+08:00")!
        let expectedEnd = ISO8601DateFormatter().date(from: "2026-08-23T18:00:00+08:00")!
        let window = HealthKitService.previousNightWindow(endingAt: end, calendar: calendar)
        #expect(window?.start == expectedStart)
        #expect(window?.end == expectedEnd)
    }

    @Test("同步批次和超时保持在移动端可恢复范围")
    func syncTransferPolicyIsBounded() {
        #expect(SyncTransferPolicy.regularBatchSize <= 8)
        #expect(SyncTransferPolicy.compatibilityConcurrency == 2)
        #expect(SyncTransferPolicy.batchRequestTimeout < SyncTransferPolicy.staleSyncInterval)
        #expect(SyncTransferPolicy.resourceTimeout < SyncTransferPolicy.staleSyncInterval)
    }

    @Test("同步错误转换为用户可理解的提示")
    func friendlySyncErrors() {
        #expect(SyncErrorPresenter.friendlyMessage("Unauthorized") == "访问密钥不正确")
        #expect(SyncErrorPresenter.friendlyMessage("The request timed out.") == "连接超时，请检查网络或更新备份服务")
    }

    @Test("额外训练组可撤销且训练草稿能够恢复")
    @MainActor
    func addedSetRemovalAndDraftRestoration() throws {
        let container = try ModelContainer(
            for: LocalRecord.self,
            PendingMutation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = AppStore(context: container.mainContext, autoSyncEnabled: false)
        store.startWorkout(quickMode: false)
        let draft = try #require(store.activeDraft)
        let exercise = try #require(draft.exercises.first)
        let plannedCount = exercise.sets.count
        exercise.sets.last?.weightText = "40"

        draft.addSet(to: exercise.id)
        #expect(exercise.sets.count == plannedCount + 1)
        #expect(exercise.sets.last?.weightText == "40")
        let addedSetID = try #require(exercise.sets.last?.id)
        #expect(draft.removeAddedSet(addedSetID, from: exercise.id))
        #expect(exercise.sets.count == plannedCount)
        let plannedSetID = try #require(exercise.sets.last?.id)
        #expect(!draft.removeAddedSet(plannedSetID, from: exercise.id))

        draft.addSet(to: exercise.id)
        store.persistActiveDraft()
        let restoredStore = AppStore(context: container.mainContext, autoSyncEnabled: false)
        #expect(restoredStore.activeDraft?.id == draft.id)
        #expect(restoredStore.activeDraft?.exercises.first?.sets.count == plannedCount + 1)
    }

    @Test("训练组左滑吸附兼顾慢开和快关")
    func swipeActionMotion() {
        #expect(SwipeActionMotion.clampedOffset(-90, actionWidth: 64) == -64)
        #expect(SwipeActionMotion.clampedOffset(12, actionWidth: 64) == 0)
        #expect(SwipeActionMotion.targetOffset(
            currentOffset: -40, translation: -40, predictedTranslation: -42, actionWidth: 64
        ) == -64)
        #expect(SwipeActionMotion.targetOffset(
            currentOffset: -44, translation: 20, predictedTranslation: 100, actionWidth: 64
        ) == 0)
    }

    @Test("组间倒计时按绝对时间取整且最后十秒只触发一次")
    func restTimerTiming() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(RestTimerTiming.remaining(until: now.addingTimeInterval(10.01), now: now) == 11)
        #expect(RestTimerTiming.remaining(until: now.addingTimeInterval(9.99), now: now) == 10)
        #expect(RestTimerTiming.remaining(until: now.addingTimeInterval(-0.01), now: now) == 0)
        #expect(RestTimerTiming.shouldTick(remaining: 10, lastTicked: nil))
        #expect(!RestTimerTiming.shouldTick(remaining: 10, lastTicked: 10))
        #expect(RestTimerTiming.shouldTick(remaining: 1, lastTicked: 2))
        #expect(!RestTimerTiming.shouldTick(remaining: 0, lastTicked: 1))
        #expect(!RestTimerTiming.shouldTick(remaining: 11, lastTicked: nil))
    }

    @Test("组间倒计时结束钟声是可播放的短音频")
    func restTimerCompletionSound() throws {
        let data = RestTimerCompletionSound.data()
        #expect(String(data: data.prefix(4), encoding: .ascii) == "RIFF")
        let player = try AVAudioPlayer(data: data)
        #expect(player.duration > 0.2)
        #expect(player.duration < 0.4)
    }

    @Test("空白点击收起键盘但输入控件和按钮不触发")
    @MainActor
    func keyboardDismissalPolicy() {
        let blank = UIView()
        #expect(KeyboardDismissalPolicy.shouldDismiss(for: blank))

        let textField = UITextField()
        #expect(!KeyboardDismissalPolicy.shouldDismiss(for: textField))
        let textFieldChild = UIView()
        textField.addSubview(textFieldChild)
        #expect(!KeyboardDismissalPolicy.shouldDismiss(for: textFieldChild))

        #expect(!KeyboardDismissalPolicy.shouldDismiss(for: UIButton()))
        #expect(!KeyboardDismissalPolicy.shouldDismiss(for: UISlider()))
    }

    @Test("训练分享会导出标准四比五合成图")
    @MainActor
    func workoutShareRendering() throws {
        let background = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400)).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
        }
        let session = WorkoutSession(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_787_587_200),
            planDay: .a,
            startedAt: Date(timeIntervalSince1970: 1_787_587_200),
            endedAt: Date(timeIntervalSince1970: 1_787_590_800),
            durationMinutes: 60,
            sets: [
                WorkoutSetRecord(
                    id: UUID(), exerciseID: "a1", setIndex: 0, weightKG: 40,
                    reps: 10, rir: 2, completed: true, stoppedForPain: false, completedAt: .now
                )
            ],
            shoulderPain: 0,
            nausea: 0,
            lowerBackDiscomfort: 0,
            note: "",
            quickMode: false
        )

        let output = try #require(WorkoutShareRenderer.render(
            image: background,
            session: session,
            overlayPosition: CGPoint(x: 0.68, y: 0.34)
        ))

        #expect(output.size == WorkoutShareRenderer.outputSize)
        #expect(output.pngData()?.isEmpty == false)
    }
}
