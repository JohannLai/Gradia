import Foundation
import SwiftData
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var workoutPlan: [WorkoutPlanItem] = SeedData.plan
    @Published private(set) var exerciseConfigurations = SeedData.configurations
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var bodyMetrics: [BodyMetric] = SeedData.baselineMetrics
    @Published private(set) var meals: [MealRecord] = []
    @Published private(set) var schedule = SeedData.initialSchedule
    @Published var healthSummary = HealthSummary.empty
    @Published var syncState: SyncState = .local
    @Published var syncMessage = "尚未配置 Google 同步"
    @Published private(set) var lastSyncAt: Date?
    @Published var activeDraft: ActiveWorkoutDraft?

    private let context: ModelContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let autoSyncEnabled: Bool
    private var autoSyncTask: Task<Void, Never>?
    private var syncStartedAt: Date?

    init(context: ModelContext, autoSyncEnabled: Bool = true) {
        self.context = context
        self.autoSyncEnabled = autoSyncEnabled
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        lastSyncAt = UserDefaults.standard.object(forKey: "googleLastSyncAt") as? Date
        loadLocalState()
    }

    var nextWorkoutItems: [WorkoutPlanItem] {
        workoutPlan.filter { $0.planDay == schedule.nextPlanDay }
    }

    var currentWeek: Int {
        max(1, min(12, (Calendar.current.dateComponents([.day], from: SeedData.cycleStart.startOfDay, to: Date.now.startOfDay).day ?? 0) / 7 + 1))
    }

    var pendingCount: Int {
        (try? context.fetchCount(FetchDescriptor<PendingMutation>())) ?? 0
    }

    var isGoogleSyncConfigured: Bool {
        UserDefaults.standard.string(forKey: "googleEndpoint") != nil &&
            KeychainStore.read(service: "FitnessApp", account: "googleToken") != nil
    }

    var latestWeight: Double? {
        let manual = bodyMetrics
            .filter { $0.weightKG != nil && $0.source == .manual }
            .sorted { $0.date > $1.date }
            .first?.weightKG
        let baseline = bodyMetrics
            .filter { $0.weightKG != nil && $0.source == .inBody }
            .sorted { $0.date > $1.date }
            .first?.weightKG
        return manual ?? baseline
    }

    var sevenDayAverageWeight: Double? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -6, to: .now.startOfDay) else { return nil }
        let daily = Dictionary(
            grouping: bodyMetrics.filter {
                $0.date >= cutoff && $0.weightKG != nil && $0.source != .healthKit
            },
            by: { $0.date.startOfDay }
        )
        let values = daily.values.compactMap { records in
            records.sorted { sourcePriority($0.source) > sourcePriority($1.source) }.first?.weightKG
        }
        guard !values.isEmpty else { return latestWeight }
        return values.reduce(0, +) / Double(values.count)
    }

    var latestWaist: Double? {
        bodyMetrics.filter { $0.waistCM != nil }.sorted { $0.date > $1.date }.first?.waistCM
    }

    var sessionsThisWeek: Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return sessions.filter { interval.contains($0.date) }.count
    }

    func startWorkout(quickMode: Bool) {
        let items = nextWorkoutItems.filter { $0.kind == .strength }
        let selected: [WorkoutPlanItem]
        if quickMode {
            selected = items
                .filter { exerciseConfigurations[$0.id]?.quickPriority != nil }
                .sorted { (exerciseConfigurations[$0.id]?.quickPriority ?? 99) < (exerciseConfigurations[$1.id]?.quickPriority ?? 99) }
                .prefix(3)
                .map { item in
                    WorkoutPlanItem(
                        id: item.id, planDay: item.planDay, order: item.order, orderLabel: item.orderLabel,
                        name: item.name, equipment: item.equipment, sets: 2, repMin: item.repMin,
                        repMax: item.repMax, durationText: item.durationText,
                        targetRIRMin: item.targetRIRMin, targetRIRMax: item.targetRIRMax,
                        restSeconds: item.restSeconds, notes: item.notes, kind: item.kind
                    )
                }
        } else {
            selected = items
        }
        activeDraft = ActiveWorkoutDraft(planDay: schedule.nextPlanDay, items: selected, quickMode: quickMode)
        persistActiveDraft()
    }

    func abandonWorkout() {
        activeDraft = nil
        removeLocalRecord(id: "activeDraft")
    }

    func completeWorkout() -> WorkoutSession? {
        guard let draft = activeDraft else { return nil }
        let session = draft.makeSession()
        sessions.append(session)
        sessions.sort { $0.startedAt > $1.startedAt }
        schedule = ScheduleEngine.advance(schedule, completionDate: session.date)
        persist(sessions, id: "sessions", kind: "workoutSessions")
        persist(schedule, id: "schedule", kind: "scheduleState")
        queueWorkout(CompleteWorkoutPayload(session: session, schedule: schedule))
        activeDraft = nil
        removeLocalRecord(id: "activeDraft")
        return session
    }

    func persistActiveDraft() {
        guard let activeDraft else {
            removeLocalRecord(id: "activeDraft")
            return
        }
        persist(ActiveWorkoutSnapshot(draft: activeDraft), id: "activeDraft", kind: "activeWorkoutDraft")
    }

    func linkHealthKitWorkout(sessionID: UUID, workoutID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].healthKitUUID = workoutID
        persist(sessions, id: "sessions", kind: "workoutSessions")
        queueWorkout(CompleteWorkoutPayload(session: sessions[index], schedule: schedule))
    }

    func importHealthWorkoutChanges(_ records: [HealthWorkoutMirror]) {
        guard !records.isEmpty else { return }
        queueHealthWorkouts(records)
    }

    func saveBodyMetric(
        weightKG: Double?, waistCM: Double?, sleepHours: Double?, steps: Int?, fatigue: Int?, note: String
    ) {
        let metric = BodyMetric(
            id: UUID(), date: .now, source: .manual, weightKG: weightKG, waistCM: waistCM,
            sleepHours: sleepHours, steps: steps, activeEnergyKCal: nil, exerciseMinutes: nil,
            restingHeartRate: nil, bodyFatPercent: nil, skeletalMuscleKG: nil,
            fatigueScore: fatigue, note: note, healthKitSourceIDs: [], updatedAt: .now
        )
        bodyMetrics.append(metric)
        bodyMetrics.sort { $0.date < $1.date }
        persist(bodyMetrics, id: "bodyMetrics", kind: "bodyMetrics")
        queue(action: "upsertBodyMetric", value: metric)
    }

    func importHealthSummary(_ summary: HealthSummary) {
        healthSummary = summary
        let metric = BodyMetric(
            id: deterministicHealthMetricID(for: .now), date: .now.startOfDay, source: .healthKit,
            weightKG: nil, waistCM: nil, sleepHours: summary.sleepHours, steps: summary.steps,
            activeEnergyKCal: summary.activeEnergyKCal, exerciseMinutes: summary.exerciseMinutes,
            restingHeartRate: summary.restingHeartRate, bodyFatPercent: nil, skeletalMuscleKG: nil,
            fatigueScore: nil, note: "Apple 健康每日汇总", healthKitSourceIDs: [], updatedAt: .now
        )
        bodyMetrics.removeAll { $0.id == metric.id }
        bodyMetrics.append(metric)
        bodyMetrics.sort { $0.date < $1.date }
        persist(bodyMetrics, id: "bodyMetrics", kind: "bodyMetrics")
        queueHealthDaily(metric)
    }

    func saveMeal(type: MealType, note: String, imageData: [Data]) throws {
        let mealID = UUID()
        let directory = try mealPhotoDirectory()
        var photos: [MealPhotoRecord] = []
        for data in imageData.prefix(4) {
            let photoID = UUID()
            let url = directory.appending(path: "\(photoID.uuidString).jpg")
            try data.write(to: url, options: .atomic)
            photos.append(.init(id: photoID, localPath: url.path, syncState: .local))
        }
        let meal = MealRecord(id: mealID, date: .now, type: type, note: note, photos: photos, aiStatus: "pending", updatedAt: .now)
        meals.append(meal)
        meals.sort { $0.date > $1.date }
        persist(meals, id: "meals", kind: "meals")
        queue(action: "upsertMeal", value: meal)
        for photo in photos {
            guard let data = try? Data(contentsOf: URL(filePath: photo.localPath)) else { continue }
            queue(action: "uploadMealPhoto", value: PhotoUploadPayload(mealID: mealID, photoID: photo.id, jpegBase64: data.base64EncodedString()))
        }
    }

    func reschedule(to date: Date) {
        schedule = ScheduleEngine.reschedule(schedule, to: date)
        persist(schedule, id: "schedule", kind: "scheduleState")
        queueLatest(action: "rescheduleWorkout", value: schedule)
    }

    func skipAndAdvance() {
        schedule = .init(
            nextPlanDay: schedule.nextPlanDay.next,
            plannedDate: ScheduleEngine.nextSuggestedDate(after: .now),
            status: .skippedAndAdvanced,
            updatedAt: .now
        )
        persist(schedule, id: "schedule", kind: "scheduleState")
        queueLatest(action: "rescheduleWorkout", value: schedule)
    }

    func sessions(in period: StatisticsPeriod, referenceDate: Date = .now) -> [WorkoutSession] {
        let calendar = Calendar.current
        let start: Date
        switch period {
        case .week:
            start = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
        case .month:
            start = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
        case .year:
            start = calendar.dateInterval(of: .year, for: referenceDate)?.start ?? referenceDate
        }
        return sessions.filter { $0.date >= start && $0.date <= referenceDate }
    }

    func muscleContributions(period: StatisticsPeriod, referenceDate: Date = .now) -> [MuscleContribution] {
        let raw = MuscleStatsCalculator.calculate(
            sessions: sessions(in: period, referenceDate: referenceDate),
            configurations: exerciseConfigurations
        )
        let days = elapsedDayCount(in: period, through: referenceDate)
        return raw.map { contribution in
            MuscleContribution(
                id: contribution.id,
                weightedSets: MuscleStatsCalculator.weeklyNormalized(
                    contribution.weightedSets, period: period, dayCount: days
                ),
                exerciseBreakdown: contribution.exerciseBreakdown.mapValues {
                    MuscleStatsCalculator.weeklyNormalized($0, period: period, dayCount: days)
                }
            )
        }
    }

    func lastSets(for exerciseID: String) -> [WorkoutSetRecord] {
        sessions.sorted { $0.startedAt > $1.startedAt }
            .first(where: { $0.sets.contains(where: { $0.exerciseID == exerciseID }) })?
            .sets.filter { $0.exerciseID == exerciseID } ?? []
    }

    func syncNow(force: Bool = true) async {
        if syncState == .syncing {
            guard let syncStartedAt,
                  Date.now.timeIntervalSince(syncStartedAt) >= SyncTransferPolicy.staleSyncInterval else {
                return
            }
            syncState = .failed
            syncMessage = "上次备份被中断，正在重新尝试"
            self.syncStartedAt = nil
        }
        guard let endpointString = UserDefaults.standard.string(forKey: "googleEndpoint")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let endpoint = URL(string: endpointString),
              let token = KeychainStore.read(service: "FitnessApp", account: "googleToken")?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            syncState = force ? .failed : .local
            syncMessage = force
                ? "请先在“更多”配置 Apps Script 地址和令牌"
                : (pendingCount > 0 ? "等待配置 Google 同步 · \(pendingCount) 条" : "尚未配置 Google 同步")
            return
        }

        let descriptor = FetchDescriptor<PendingMutation>(sortBy: [SortDescriptor(\.createdAt)])
        guard let allPending = try? context.fetch(descriptor), !allPending.isEmpty else {
            syncState = .synced
            syncMessage = "所有数据已同步"
            return
        }

        let now = Date.now
        let pending = allPending.filter { mutation in
            force || mutation.retryCount == 0 ||
                now.timeIntervalSince(mutation.createdAt) >= SyncRetryPolicy.delay(forRetryCount: mutation.retryCount)
        }
        guard !pending.isEmpty else {
            syncState = .local
            let delay = allPending.map {
                max(0, SyncRetryPolicy.delay(forRetryCount: $0.retryCount) - now.timeIntervalSince($0.createdAt))
            }.min() ?? 2
            syncMessage = "等待网络重试 · \(allPending.count) 条"
            scheduleAutoSync(after: max(1, delay))
            return
        }

        syncState = .syncing
        syncStartedAt = .now
        syncMessage = "正在备份 0 / \(pending.count)"
        defer {
            syncStartedAt = nil
            if syncState == .syncing {
                syncState = .failed
                syncMessage = "备份被系统中断，稍后将自动重试"
                scheduleAutoSync(after: 2)
            }
        }
        var processed = 0
        var succeeded = 0
        var failed = 0
        var stoppedForNetworkError = false

        let regular = pending.filter { $0.action != "uploadMealPhoto" }
        for batch in regular.chunked(maxSize: SyncTransferPolicy.regularBatchSize) {
            do {
                try Task.checkCancellation()
                let results = try await sendBatchWithCompatibilityFallback(
                    batch, endpoint: endpoint, token: token
                )
                let byID = Dictionary(uniqueKeysWithValues: results.map { ($0.requestID, $0) })
                for mutation in batch {
                    if let result = byID[mutation.requestID], result.succeeded {
                        context.delete(mutation)
                        succeeded += 1
                    } else {
                        recordFailure(
                            mutation,
                            message: byID[mutation.requestID]?.error ?? "服务端未返回此记录的结果"
                        )
                        failed += 1
                    }
                    processed += 1
                }
                try context.save()
                syncStartedAt = .now
                syncMessage = "正在备份 \(processed) / \(pending.count)"
            } catch {
                batch.forEach { recordFailure($0, message: error.localizedDescription) }
                failed += batch.count
                processed += batch.count
                try? context.save()
                syncStartedAt = .now
                stoppedForNetworkError = true
                break
            }
        }

        let photos = stoppedForNetworkError ? [] : pending.filter { $0.action == "uploadMealPhoto" }
        for mutation in photos {
            do {
                try Task.checkCancellation()
                try await GoogleAPIClient.shared.send(
                    endpoint: endpoint, token: token, action: mutation.action,
                    requestID: mutation.requestID, payload: mutation.payload
                )
                context.delete(mutation)
                try context.save()
                succeeded += 1
                processed += 1
                syncStartedAt = .now
                syncMessage = "正在备份 \(processed) / \(pending.count)"
            } catch {
                recordFailure(mutation, message: error.localizedDescription)
                try? context.save()
                failed += 1
                processed += 1
                syncStartedAt = .now
            }
        }

        if succeeded > 0 {
            lastSyncAt = .now
            UserDefaults.standard.set(lastSyncAt, forKey: "googleLastSyncAt")
        }
        if failed == 0 {
            if pendingCount == 0 {
                syncState = .synced
                syncMessage = "刚刚同步完成"
            } else {
                syncState = .local
                syncMessage = "本轮完成 · \(pendingCount) 条新记录等待同步"
                scheduleAutoSync(after: 1)
            }
        } else {
            syncState = .failed
            let remaining = (try? context.fetch(descriptor)) ?? []
            let errorDetail = remaining.compactMap(\.lastError).first.map(SyncErrorPresenter.friendlyMessage)
            if let errorDetail {
                syncMessage = "备份失败：\(errorDetail)"
            } else {
                syncMessage = succeeded > 0
                    ? "已备份 \(succeeded) 条，\(pendingCount) 条稍后重试"
                    : "备份失败，\(pendingCount) 条稍后重试"
            }
            let retryDelay = (try? context.fetch(descriptor))?
                .map { SyncRetryPolicy.delay(forRetryCount: $0.retryCount) }
                .min() ?? 2
            scheduleAutoSync(after: max(2, retryDelay))
        }
    }

    private func sendBatchWithCompatibilityFallback(
        _ mutations: [PendingMutation], endpoint: URL, token: String
    ) async throws -> [GoogleAPIClient.BatchResult] {
        let items = mutations.map {
            GoogleAPIClient.BatchItem(requestID: $0.requestID, action: $0.action, payload: $0.payload)
        }
        do {
            return try await GoogleAPIClient.shared.sendBatch(endpoint: endpoint, token: token, items: items)
        } catch GoogleAPIError.server(let message) where message.contains("Unsupported action: syncBatch") {
            syncMessage = "备份服务版本较旧，正在兼容处理"
            var results: [GoogleAPIClient.BatchResult] = []
            for group in items.chunked(maxSize: SyncTransferPolicy.compatibilityConcurrency) {
                let groupResults = await withTaskGroup(of: GoogleAPIClient.BatchResult.self) { taskGroup in
                    for item in group {
                        taskGroup.addTask {
                            do {
                                try await GoogleAPIClient.shared.send(
                                    endpoint: endpoint,
                                    token: token,
                                    action: item.action,
                                    requestID: item.requestID,
                                    payload: item.payload
                                )
                                return .init(requestID: item.requestID, error: nil)
                            } catch {
                                return .init(requestID: item.requestID, error: error.localizedDescription)
                            }
                        }
                    }
                    var values: [GoogleAPIClient.BatchResult] = []
                    for await value in taskGroup { values.append(value) }
                    return values
                }
                results.append(contentsOf: groupResults)
            }
            return results
        }
    }

    private func recordFailure(_ mutation: PendingMutation, message: String) {
        mutation.retryCount += 1
        mutation.lastError = message
        mutation.createdAt = .now
    }

    private func scheduleAutoSync(after delay: TimeInterval = 2) {
        guard autoSyncEnabled else { return }
        guard UserDefaults.standard.string(forKey: "googleEndpoint") != nil,
              KeychainStore.read(service: "FitnessApp", account: "googleToken") != nil else { return }
        autoSyncTask?.cancel()
        autoSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.syncNow(force: false)
        }
    }

    private func loadLocalState() {
        guard let records = try? context.fetch(FetchDescriptor<LocalRecord>()) else { return }
        for record in records {
            switch record.id {
            case "sessions": sessions = (try? decoder.decode([WorkoutSession].self, from: record.payload)) ?? []
            case "bodyMetrics": bodyMetrics = (try? decoder.decode([BodyMetric].self, from: record.payload)) ?? SeedData.baselineMetrics
            case "meals": meals = (try? decoder.decode([MealRecord].self, from: record.payload)) ?? []
            case "schedule": schedule = (try? decoder.decode(ScheduleState.self, from: record.payload)) ?? SeedData.initialSchedule
            case "activeDraft":
                if let snapshot = try? decoder.decode(ActiveWorkoutSnapshot.self, from: record.payload) {
                    activeDraft = snapshot.restore(plan: workoutPlan)
                }
            default: break
            }
        }
        if !records.contains(where: { $0.id == "bodyMetrics" }) {
            persist(bodyMetrics, id: "bodyMetrics", kind: "bodyMetrics")
        }
        if !records.contains(where: { $0.id == "schedule" }) {
            persist(schedule, id: "schedule", kind: "scheduleState")
        }
    }

    private func persist<T: Encodable>(_ value: T, id: String, kind: String) {
        guard let data = try? encoder.encode(value) else { return }
        let descriptor = FetchDescriptor<LocalRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.payload = data
            existing.updatedAt = .now
        } else {
            context.insert(LocalRecord(id: id, kind: kind, payload: data))
        }
        try? context.save()
    }

    private func queue<T: Encodable>(action: String, value: T) {
        guard let data = try? encoder.encode(value) else { return }
        context.insert(PendingMutation(action: action, payload: data))
        markQueueChanged()
    }

    private func queueWorkout(_ payload: CompleteWorkoutPayload) {
        queueLatest(action: "completeWorkout", value: payload) {
            $0.session.id == payload.session.id
        }
    }

    private func queueHealthWorkouts(_ records: [HealthWorkoutMirror]) {
        if syncState == .syncing {
            queue(action: "upsertHealthWorkouts", value: records)
            return
        }
        let descriptor = FetchDescriptor<PendingMutation>(
            predicate: #Predicate { $0.action == "upsertHealthWorkouts" }
        )
        let pending = (try? context.fetch(descriptor)) ?? []
        var merged = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for mutation in pending {
            guard let existing = try? decoder.decode([HealthWorkoutMirror].self, from: mutation.payload) else { continue }
            for record in existing where (merged[record.id]?.updatedAt ?? .distantPast) < record.updatedAt {
                merged[record.id] = record
            }
        }
        pending.forEach(context.delete)
        queue(action: "upsertHealthWorkouts", value: merged.values.sorted { $0.updatedAt < $1.updatedAt })
    }

    private func queueLatest<T: Codable>(
        action: String,
        value: T,
        matches: ((T) -> Bool)? = nil
    ) {
        guard let data = try? encoder.encode(value) else { return }
        if syncState == .syncing {
            context.insert(PendingMutation(action: action, payload: data))
            markQueueChanged()
            return
        }
        let descriptor = FetchDescriptor<PendingMutation>(predicate: #Predicate { $0.action == action })
        let candidates = (try? context.fetch(descriptor)) ?? []
        let matching = candidates.filter { mutation in
            guard let decoded = try? decoder.decode(T.self, from: mutation.payload) else { return false }
            return matches?(decoded) ?? true
        }
        if let target = matching.first {
            target.payload = data
            target.requestID = UUID().uuidString
            target.createdAt = .now
            target.retryCount = 0
            target.lastError = nil
            matching.dropFirst().forEach(context.delete)
        } else {
            context.insert(PendingMutation(action: action, payload: data))
        }
        markQueueChanged()
    }

    /// A launch can refresh today's HealthKit summary many times. Keep only the
    /// newest pending value for that deterministic daily metric ID.
    private func queueHealthDaily(_ metric: BodyMetric) {
        queueLatest(action: "upsertHealthDaily", value: metric) { $0.id == metric.id }
    }

    private func markQueueChanged() {
        try? context.save()
        if syncState != .syncing {
            syncState = .local
            syncMessage = "有 \(pendingCount) 条记录等待同步"
        }
        scheduleAutoSync()
    }

    private func mealPhotoDirectory() throws -> URL {
        let root = URL.applicationSupportDirectory.appending(path: "MealPhotos", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func removeLocalRecord(id: String) {
        let descriptor = FetchDescriptor<LocalRecord>(predicate: #Predicate { $0.id == id })
        if let record = try? context.fetch(descriptor).first {
            context.delete(record)
            try? context.save()
        }
    }

    private func deterministicHealthMetricID(for date: Date) -> UUID {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let value = String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        let suffix = value.padding(toLength: 12, withPad: "0", startingAt: 0)
        return UUID(uuidString: "00000000-0000-4000-8000-\(suffix)") ?? UUID()
    }

    private func sourcePriority(_ source: MetricSource) -> Int {
        switch source {
        case .manual: 3
        case .healthKit: 2
        case .inBody: 1
        }
    }

    private func elapsedDayCount(in period: StatisticsPeriod, through referenceDate: Date) -> Int {
        let component: Calendar.Component
        switch period {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        let start = Calendar.current.dateInterval(of: component, for: referenceDate)?.start ?? referenceDate
        return max(1, (Calendar.current.dateComponents([.day], from: start.startOfDay, to: referenceDate.startOfDay).day ?? 0) + 1)
    }
}

private struct CompleteWorkoutPayload: Codable {
    let session: WorkoutSession
    let schedule: ScheduleState
}

private struct PhotoUploadPayload: Codable {
    let mealID: UUID
    let photoID: UUID
    let jpegBase64: String
}

private extension Array {
    func chunked(maxSize: Int) -> [[Element]] {
        guard maxSize > 0 else { return [] }
        return stride(from: 0, to: count, by: maxSize).map {
            Array(self[$0 ..< Swift.min($0 + maxSize, count)])
        }
    }
}

private struct ActiveWorkoutSnapshot: Codable {
    let id: UUID
    let planDay: PlanDay
    let itemIDs: [String]
    let quickMode: Bool
    let startedAt: Date
    let exercises: [ExerciseSnapshot]
    let shoulderPain: Int
    let nausea: Int
    let lowerBackDiscomfort: Int
    let note: String

    @MainActor
    init(draft: ActiveWorkoutDraft) {
        id = draft.id
        planDay = draft.planDay
        itemIDs = draft.items.map(\.id)
        quickMode = draft.quickMode
        startedAt = draft.startedAt
        exercises = draft.exercises.map { exercise in
            ExerciseSnapshot(
                itemID: exercise.item.id,
                sets: exercise.sets.map {
                    SetSnapshot(
                        id: $0.id, weightText: $0.weightText, repsText: $0.repsText,
                        rirText: $0.rirText, completed: $0.completed,
                        stoppedForPain: $0.stoppedForPain
                    )
                }
            )
        }
        shoulderPain = draft.shoulderPain
        nausea = draft.nausea
        lowerBackDiscomfort = draft.lowerBackDiscomfort
        note = draft.note
    }

    @MainActor
    func restore(plan: [WorkoutPlanItem]) -> ActiveWorkoutDraft? {
        let itemsByID = Dictionary(uniqueKeysWithValues: plan.map { ($0.id, $0) })
        let restoredItems = itemIDs.compactMap { itemsByID[$0] }
        guard restoredItems.count == itemIDs.count else { return nil }
        let draft = ActiveWorkoutDraft(
            id: id, planDay: planDay, items: restoredItems,
            quickMode: quickMode, startedAt: startedAt
        )
        draft.exercises = exercises.compactMap { snapshot in
            guard let item = itemsByID[snapshot.itemID] else { return nil }
            let sets = snapshot.sets.map {
                SetDraft(
                    id: $0.id, weightText: $0.weightText, repsText: $0.repsText,
                    rirText: $0.rirText, completed: $0.completed,
                    stoppedForPain: $0.stoppedForPain
                )
            }
            return ExerciseDraft(item: item, sets: sets)
        }
        draft.shoulderPain = shoulderPain
        draft.nausea = nausea
        draft.lowerBackDiscomfort = lowerBackDiscomfort
        draft.note = note
        return draft
    }
}

private struct ExerciseSnapshot: Codable {
    let itemID: String
    let sets: [SetSnapshot]
}

private struct SetSnapshot: Codable {
    let id: UUID
    let weightText: String
    let repsText: String
    let rirText: String
    let completed: Bool
    let stoppedForPain: Bool
}

@MainActor
final class ActiveWorkoutDraft: ObservableObject {
    let id: UUID
    let planDay: PlanDay
    let items: [WorkoutPlanItem]
    let quickMode: Bool
    let startedAt: Date
    @Published var exercises: [ExerciseDraft]
    @Published var shoulderPain = 0
    @Published var nausea = 0
    @Published var lowerBackDiscomfort = 0
    @Published var note = ""

    init(
        id: UUID = UUID(), planDay: PlanDay, items: [WorkoutPlanItem],
        quickMode: Bool, startedAt: Date = .now
    ) {
        self.id = id
        self.planDay = planDay
        self.items = items
        self.quickMode = quickMode
        self.startedAt = startedAt
        exercises = items.map { ExerciseDraft(item: $0) }
    }

    var completedSetCount: Int {
        exercises.flatMap(\.sets).filter(\.completed).count
    }

    var totalSetCount: Int {
        exercises.flatMap(\.sets).count
    }

    func addSet(to exerciseID: String) {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }) else { return }
        objectWillChange.send()
        exercise.sets.append(SetDraft(weightText: exercise.sets.last?.weightText ?? ""))
    }

    @discardableResult
    func removeAddedSet(_ setID: UUID, from exerciseID: String) -> Bool {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }),
              let index = exercise.sets.firstIndex(where: { $0.id == setID }),
              index >= (exercise.item.sets ?? 0) else { return false }
        objectWillChange.send()
        exercise.sets.remove(at: index)
        return true
    }

    func makeSession() -> WorkoutSession {
        let end = Date.now
        let records = exercises.flatMap { exercise in
            exercise.sets.enumerated().map { index, draft in
                WorkoutSetRecord(
                    id: draft.id, exerciseID: exercise.item.id, setIndex: index + 1,
                    weightKG: draft.weightKG, reps: draft.reps, rir: draft.rir,
                    completed: draft.completed, stoppedForPain: draft.stoppedForPain,
                    completedAt: draft.completed ? end : nil
                )
            }
        }
        return WorkoutSession(
            id: id, date: startedAt, planDay: planDay, startedAt: startedAt, endedAt: end,
            durationMinutes: max(1, Int(end.timeIntervalSince(startedAt) / 60)), sets: records,
            shoulderPain: shoulderPain, nausea: nausea, lowerBackDiscomfort: lowerBackDiscomfort,
            note: note, quickMode: quickMode
        )
    }
}

@MainActor
final class ExerciseDraft: ObservableObject, Identifiable {
    let id: String
    let item: WorkoutPlanItem
    @Published var sets: [SetDraft]

    init(item: WorkoutPlanItem, sets: [SetDraft]? = nil) {
        self.id = item.id
        self.item = item
        self.sets = sets ?? (0..<(item.sets ?? 0)).map { _ in SetDraft() }
    }
}

@MainActor
final class SetDraft: ObservableObject, Identifiable {
    let id: UUID
    @Published var weightText = ""
    @Published var repsText = ""
    @Published var rirText = ""
    @Published var completed = false
    @Published var stoppedForPain = false

    init(
        id: UUID = UUID(), weightText: String = "", repsText: String = "",
        rirText: String = "", completed: Bool = false, stoppedForPain: Bool = false
    ) {
        self.id = id
        self.weightText = weightText
        self.repsText = repsText
        self.rirText = rirText
        self.completed = completed
        self.stoppedForPain = stoppedForPain
    }

    var weightKG: Double? { Double(weightText.replacingOccurrences(of: ",", with: ".")) }
    var reps: Int { Int(repsText) ?? 0 }
    var rir: Double? { Double(rirText.replacingOccurrences(of: ",", with: ".")) }
}
