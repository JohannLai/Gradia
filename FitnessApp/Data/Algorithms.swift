import Foundation

enum ProgressionEngine {
    static func recommend(
        item: WorkoutPlanItem,
        previousSets: [WorkoutSetRecord],
        shoulderPain: Int,
        nausea: Int,
        lowerBackDiscomfort: Int,
        configuration: ExerciseConfiguration?
    ) -> ProgressionRecommendation {
        guard item.kind == .strength, !previousSets.isEmpty else {
            return .init(action: .keep, title: "先校准工作重量", detail: "按目标 RIR 完成第一轮，保守记录动作反应。", suggestedWeight: nil)
        }

        let hadPainStop = previousSets.contains(where: { $0.stoppedForPain })
        let completed = previousSets.filter { $0.completed && !$0.stoppedForPain }
        let lastWeight = completed.compactMap(\.weightKG).last

        if shoulderPain >= 3 || hadPainStop {
            return .init(action: .safetyHold, title: "暂停加重", detail: "肩痛达到 3/10 或出现疼痛中止，优先调整动作耐受。", suggestedWeight: lastWeight)
        }
        if nausea >= 5 || lowerBackDiscomfort >= 5 {
            return .init(action: .safetyHold, title: "保持或降低负荷", detail: "异常评分偏高，延长休息并减少当日疲劳。", suggestedWeight: lastWeight)
        }

        let belowMinimum = completed.contains { $0.reps < (item.repMin ?? 0) }
        let rirTooLow = completed.compactMap(\.rir).contains { $0 < 1 }
        if belowMinimum || rirTooLow {
            return .init(action: .reduce, title: "先恢复次数质量", detail: "出现低于次数下限或 RIR 过低，下次保持或小幅降重。", suggestedWeight: lastWeight)
        }

        let allAtTop = completed.count == item.sets && completed.allSatisfy { $0.reps >= (item.repMax ?? .max) }
        let targetRIR = item.targetRIRMin ?? 1
        let rirQualified = completed.compactMap(\.rir).last.map { $0 >= targetRIR } ?? true
        if allAtTop, rirQualified, let lastWeight {
            let increment = configuration?.increment ?? 2.5
            let nextWeight = configuration?.machineIncrement == true ? nil : lastWeight + increment
            return .init(
                action: .increase,
                title: configuration?.machineIncrement == true ? "下次增加一个档位" : "下次建议加重",
                detail: "全部工作组达到次数上限，RIR 与症状均达标。",
                suggestedWeight: nextWeight
            )
        }

        let totalReps = completed.reduce(0) { $0 + $1.reps }
        return .init(
            action: .keep,
            title: "保持重量，增加总次数",
            detail: "上次共完成 \(totalReps) 次；本次争取在动作质量不下降时超过它。",
            suggestedWeight: lastWeight
        )
    }
}

enum ScheduleEngine {
    static func nextSuggestedDate(after date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: date)
        for offset in 2...4 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            if weekday != 1 { return candidate }
        }
        return calendar.date(byAdding: .day, value: 2, to: start) ?? start
    }

    static func advance(_ state: ScheduleState, completionDate: Date) -> ScheduleState {
        .init(
            nextPlanDay: state.nextPlanDay.next,
            plannedDate: nextSuggestedDate(after: completionDate),
            status: .planned,
            updatedAt: .now
        )
    }

    static func reschedule(_ state: ScheduleState, to date: Date) -> ScheduleState {
        .init(nextPlanDay: state.nextPlanDay, plannedDate: date, status: .rescheduled, updatedAt: .now)
    }
}

enum MuscleStatsCalculator {
    static func calculate(
        sessions: [WorkoutSession],
        configurations: [String: ExerciseConfiguration]
    ) -> [MuscleContribution] {
        var totals: [MuscleGroup: Double] = [:]
        var breakdown: [MuscleGroup: [String: Double]] = [:]

        for session in sessions {
            for set in session.sets {
                guard set.completed,
                      set.reps > 0,
                      !set.stoppedForPain,
                      set.rir.map({ (0...4).contains($0) }) ?? true,
                      let config = configurations[set.exerciseID],
                      !config.excludesMuscleStats else { continue }

                for muscle in config.primaryMuscles {
                    totals[muscle, default: 0] += 1
                    breakdown[muscle, default: [:]][set.exerciseID, default: 0] += 1
                }
                for muscle in config.secondaryMuscles {
                    totals[muscle, default: 0] += 0.5
                    breakdown[muscle, default: [:]][set.exerciseID, default: 0] += 0.5
                }
            }
        }

        return MuscleGroup.allCases.map {
            MuscleContribution(id: $0, weightedSets: totals[$0, default: 0], exerciseBreakdown: breakdown[$0, default: [:]])
        }
    }

    static func weeklyNormalized(_ value: Double, period: StatisticsPeriod, dayCount: Int) -> Double {
        guard period != .week else { return value }
        return value / max(Double(dayCount) / 7, 1)
    }

    static func intensityLevel(for weeklySets: Double) -> Int {
        switch weeklySets {
        case ...0: 0
        case ..<3: 1
        case ..<6: 2
        case ..<9: 3
        default: 4
        }
    }
}
