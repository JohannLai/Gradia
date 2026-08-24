import Foundation
import SwiftUI

enum PlanDay: String, Codable, CaseIterable, Identifiable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"

    var id: String { rawValue }

    var next: PlanDay {
        switch self {
        case .a: .b
        case .b: .c
        case .c: .a
        }
    }

    var focus: String {
        switch self {
        case .a: "胸 + 股四头"
        case .b: "背部 + 后侧链"
        case .c: "腿部第二刺激 + 胸背补量"
        }
    }
}

enum PlanItemKind: String, Codable, Sendable {
    case warmup
    case strength
    case cardio
}

struct WorkoutPlanItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let planDay: PlanDay
    let order: Int
    let orderLabel: String
    let name: String
    let equipment: String
    let sets: Int?
    let repMin: Int?
    let repMax: Int?
    let durationText: String?
    let targetRIRMin: Double?
    let targetRIRMax: Double?
    let restSeconds: ClosedRange<Int>?
    let notes: String
    let kind: PlanItemKind

    enum CodingKeys: String, CodingKey {
        case id, planDay, order, orderLabel, name, equipment, sets, repMin, repMax
        case durationText, targetRIRMin, targetRIRMax, restLower, restUpper, notes, kind
    }

    init(
        id: String,
        planDay: PlanDay,
        order: Int,
        orderLabel: String,
        name: String,
        equipment: String,
        sets: Int?,
        repMin: Int?,
        repMax: Int?,
        durationText: String? = nil,
        targetRIRMin: Double?,
        targetRIRMax: Double?,
        restSeconds: ClosedRange<Int>?,
        notes: String,
        kind: PlanItemKind
    ) {
        self.id = id
        self.planDay = planDay
        self.order = order
        self.orderLabel = orderLabel
        self.name = name
        self.equipment = equipment
        self.sets = sets
        self.repMin = repMin
        self.repMax = repMax
        self.durationText = durationText
        self.targetRIRMin = targetRIRMin
        self.targetRIRMax = targetRIRMax
        self.restSeconds = restSeconds
        self.notes = notes
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        planDay = try values.decode(PlanDay.self, forKey: .planDay)
        order = try values.decode(Int.self, forKey: .order)
        orderLabel = try values.decode(String.self, forKey: .orderLabel)
        name = try values.decode(String.self, forKey: .name)
        equipment = try values.decode(String.self, forKey: .equipment)
        sets = try values.decodeIfPresent(Int.self, forKey: .sets)
        repMin = try values.decodeIfPresent(Int.self, forKey: .repMin)
        repMax = try values.decodeIfPresent(Int.self, forKey: .repMax)
        durationText = try values.decodeIfPresent(String.self, forKey: .durationText)
        targetRIRMin = try values.decodeIfPresent(Double.self, forKey: .targetRIRMin)
        targetRIRMax = try values.decodeIfPresent(Double.self, forKey: .targetRIRMax)
        if let lower = try values.decodeIfPresent(Int.self, forKey: .restLower),
           let upper = try values.decodeIfPresent(Int.self, forKey: .restUpper) {
            restSeconds = lower...upper
        } else {
            restSeconds = nil
        }
        notes = try values.decode(String.self, forKey: .notes)
        kind = try values.decode(PlanItemKind.self, forKey: .kind)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(planDay, forKey: .planDay)
        try values.encode(order, forKey: .order)
        try values.encode(orderLabel, forKey: .orderLabel)
        try values.encode(name, forKey: .name)
        try values.encode(equipment, forKey: .equipment)
        try values.encodeIfPresent(sets, forKey: .sets)
        try values.encodeIfPresent(repMin, forKey: .repMin)
        try values.encodeIfPresent(repMax, forKey: .repMax)
        try values.encodeIfPresent(durationText, forKey: .durationText)
        try values.encodeIfPresent(targetRIRMin, forKey: .targetRIRMin)
        try values.encodeIfPresent(targetRIRMax, forKey: .targetRIRMax)
        try values.encodeIfPresent(restSeconds?.lowerBound, forKey: .restLower)
        try values.encodeIfPresent(restSeconds?.upperBound, forKey: .restUpper)
        try values.encode(notes, forKey: .notes)
        try values.encode(kind, forKey: .kind)
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case chest
    case frontDelts
    case sideDelts
    case rearDelts
    case lats
    case upperBack
    case biceps
    case triceps
    case forearms
    case abs
    case lowerBack
    case glutes
    case quads
    case hamstrings
    case calves

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "胸肌"
        case .frontDelts: "三角肌前束"
        case .sideDelts: "三角肌侧束"
        case .rearDelts: "三角肌后束"
        case .lats: "背阔肌"
        case .upperBack: "上背 / 斜方肌"
        case .biceps: "肱二头肌"
        case .triceps: "肱三头肌"
        case .forearms: "前臂"
        case .abs: "腹肌"
        case .lowerBack: "竖脊肌 / 下背"
        case .glutes: "臀肌"
        case .quads: "股四头肌"
        case .hamstrings: "腘绳肌"
        case .calves: "小腿"
        }
    }
}

struct ExerciseConfiguration: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let primaryMuscles: Set<MuscleGroup>
    let secondaryMuscles: Set<MuscleGroup>
    let excludesMuscleStats: Bool
    let increment: Double?
    let machineIncrement: Bool
    let tracksShoulderPain: Bool
    let tracksNausea: Bool
    let tracksLowerBack: Bool
    let quickPriority: Int?
    let substituteExerciseID: String?
}

struct WorkoutSetRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let exerciseID: String
    let setIndex: Int
    var weightKG: Double?
    var reps: Int
    var rir: Double?
    var completed: Bool
    var stoppedForPain: Bool
    var completedAt: Date?
}

struct WorkoutSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let planDay: PlanDay
    let startedAt: Date
    let endedAt: Date
    let durationMinutes: Int
    let sets: [WorkoutSetRecord]
    let shoulderPain: Int
    let nausea: Int
    let lowerBackDiscomfort: Int
    let note: String
    let quickMode: Bool
    var healthKitUUID: UUID?

    var totalVolume: Double {
        sets.reduce(0) { result, set in
            guard set.completed, !set.stoppedForPain, let weight = set.weightKG else { return result }
            return result + weight * Double(set.reps)
        }
    }

    var completedSetCount: Int {
        sets.filter { $0.completed && !$0.stoppedForPain }.count
    }
}

enum MetricSource: String, Codable, Sendable {
    case manual
    case healthKit
    case inBody
}

struct BodyMetric: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let source: MetricSource
    var weightKG: Double?
    var waistCM: Double?
    var sleepHours: Double?
    var steps: Int?
    var activeEnergyKCal: Double?
    var exerciseMinutes: Double?
    var restingHeartRate: Double?
    var bodyFatPercent: Double?
    var skeletalMuscleKG: Double?
    var fatigueScore: Int?
    var note: String
    var healthKitSourceIDs: [String]
    var updatedAt: Date
}

struct HealthWorkoutMirror: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var sourceBundleID: String
    var activityType: UInt
    var startedAt: Date?
    var endedAt: Date?
    var durationMinutes: Double?
    var activeEnergyKCal: Double?
    var averageHeartRate: Double?
    var appSessionID: UUID?
    var deleted: Bool
    var updatedAt: Date
}

enum MealType: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"
    case snack = "加餐"

    var id: String { rawValue }
}

struct MealPhotoRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let localPath: String
    var driveFileID: String?
    var driveURL: String?
    var syncState: SyncState
}

struct MealRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let type: MealType
    let note: String
    var photos: [MealPhotoRecord]
    var aiStatus: String
    let updatedAt: Date
}

enum SyncState: String, Codable, Sendable {
    case local
    case syncing
    case synced
    case failed
}

enum ScheduleStatus: String, Codable, Sendable {
    case planned
    case rescheduled
    case skippedAndAdvanced
}

struct ScheduleState: Codable, Hashable, Sendable {
    var nextPlanDay: PlanDay
    var plannedDate: Date
    var status: ScheduleStatus
    var updatedAt: Date
}

struct HealthSummary: Sendable {
    var steps: Int?
    var sleepHours: Double?
    var activeEnergyKCal: Double?
    var exerciseMinutes: Double?
    var restingHeartRate: Double?

    static let empty = HealthSummary()
}

enum ProgressionAction: String, Sendable {
    case increase
    case keep
    case reduce
    case safetyHold
}

struct ProgressionRecommendation: Sendable, Equatable {
    let action: ProgressionAction
    let title: String
    let detail: String
    let suggestedWeight: Double?
}

struct MuscleContribution: Identifiable, Sendable {
    let id: MuscleGroup
    let weightedSets: Double
    let exerciseBreakdown: [String: Double]
}

enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week = "周"
    case month = "月"
    case year = "年"

    var id: String { rawValue }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
