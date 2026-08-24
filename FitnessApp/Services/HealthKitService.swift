import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshAt: Date?

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        [
            HKQuantityTypeIdentifier.stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .heartRate,
            .restingHeartRate
        ].compactMap(HKQuantityType.quantityType(forIdentifier:)).forEach { types.insert($0) }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        return types
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            lastError = "此设备不支持 Apple 健康"
            return
        }
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: readTypes)
            isAuthorized = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func fetchTodaySummary() async -> HealthSummary {
        guard HKHealthStore.isHealthDataAvailable() else { return .empty }
        let start = Calendar.current.startOfDay(for: .now)
        async let steps = cumulativeQuantity(.stepCount, unit: .count(), start: start)
        async let energy = cumulativeQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: start)
        async let exercise = cumulativeQuantity(.appleExerciseTime, unit: .minute(), start: start)
        // Apple Health commonly calculates resting heart rate once per day and
        // today's value may not exist yet. Show the latest available sample.
        async let resting = latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: nil)
        async let sleep = sleepHours(endingAt: .now)
        let summary = await HealthSummary(
            steps: steps.map { Int($0.rounded()) },
            sleepHours: sleep,
            activeEnergyKCal: energy,
            exerciseMinutes: exercise,
            restingHeartRate: resting
        )
        lastRefreshAt = .now
        return summary
    }

    func saveWorkout(_ session: WorkoutSession) async throws -> UUID {
        let metadata: [String: Any] = [
            HKMetadataKeyExternalUUID: session.id.uuidString,
            "FitnessPlanDay": session.planDay.rawValue,
            "FitnessQuickMode": session.quickMode
        ]
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .unknown
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: session.startedAt)
        try await builder.addMetadata(metadata)
        try await builder.endCollection(at: session.endedAt)
        guard let workout = try await builder.finishWorkout() else {
            throw HealthKitServiceError.workoutNotCreated
        }
        return workout.uuid
    }

    /// Mirrors workout edits and deletions incrementally. AppStore writes the
    /// returned records to its durable outbox before any network sync occurs.
    func fetchWorkoutChanges() async throws -> [HealthWorkoutMirror] {
        let anchor = loadWorkoutAnchor()
        let result: ([HKWorkout], [HKDeletedObject], HKQueryAnchor?) = try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: HKObjectType.workoutType(), predicate: nil, anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deleted, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout] ?? [], deleted ?? [], newAnchor))
            }
            store.execute(query)
        }

        let imported = result.0.map { workout in
            HealthWorkoutMirror(
                id: workout.uuid,
                sourceBundleID: workout.sourceRevision.source.bundleIdentifier,
                activityType: workout.workoutActivityType.rawValue,
                startedAt: workout.startDate,
                endedAt: workout.endDate,
                durationMinutes: workout.duration / 60,
                activeEnergyKCal: nil,
                averageHeartRate: nil,
                appSessionID: (workout.metadata?[HKMetadataKeyExternalUUID] as? String).flatMap(UUID.init(uuidString:)),
                deleted: false,
                updatedAt: .now
            )
        }
        let removed = result.1.map {
            HealthWorkoutMirror(
                id: $0.uuid, sourceBundleID: "", activityType: 0,
                startedAt: nil, endedAt: nil, durationMinutes: nil,
                activeEnergyKCal: nil, averageHeartRate: nil, appSessionID: nil,
                deleted: true, updatedAt: .now
            )
        }
        if let newAnchor = result.2 { saveWorkoutAnchor(newAnchor) }
        return imported + removed
    }

    private func loadWorkoutAnchor() -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: "healthkit.workouts.anchor") else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveWorkoutAnchor(_ anchor: HKQueryAnchor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "healthkit.workouts.anchor")
        }
    }

    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date?
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = start.map { HKQuery.predicateForSamples(withStart: $0, end: .now) }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func cumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func sleepHours(endingAt end: Date) async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let window = Self.previousNightWindow(endingAt: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let intervals = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .compactMap { sample -> DateInterval? in
                        let start = max(sample.startDate, window.start)
                        let end = min(sample.endDate, window.end)
                        return end > start ? DateInterval(start: start, end: end) : nil
                    }
                // Sleep stages from the Watch and third-party apps can overlap.
                // Merge their intervals so the same minute is never counted twice.
                let seconds = Self.mergedDuration(of: intervals)
                continuation.resume(returning: seconds > 0 ? seconds / 3600 : nil)
            }
            store.execute(query)
        }
    }

    nonisolated static func previousNightWindow(
        endingAt end: Date,
        calendar: Calendar = .current
    ) -> DateInterval? {
        let startOfToday = calendar.startOfDay(for: end)
        guard let start = calendar.date(byAdding: .hour, value: -8, to: startOfToday),
              let eveningCutoff = calendar.date(byAdding: .hour, value: 18, to: startOfToday) else {
            return nil
        }
        let boundedEnd = min(end, eveningCutoff)
        guard boundedEnd > start else { return nil }
        return DateInterval(start: start, end: boundedEnd)
    }

    nonisolated static func mergedDuration(of intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        guard let first = sorted.first else { return 0 }

        var total: TimeInterval = 0
        var currentStart = first.start
        var currentEnd = first.end

        for interval in sorted.dropFirst() {
            if interval.start <= currentEnd {
                currentEnd = max(currentEnd, interval.end)
            } else {
                total += currentEnd.timeIntervalSince(currentStart)
                currentStart = interval.start
                currentEnd = interval.end
            }
        }
        return total + currentEnd.timeIntervalSince(currentStart)
    }
}

private enum HealthKitServiceError: LocalizedError {
    case workoutNotCreated

    var errorDescription: String? { "Apple 健康未能创建训练记录" }
}
