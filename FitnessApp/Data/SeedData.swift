import Foundation

enum SeedData {
    static let sourceSpreadsheetID = "1ZykWiFxfaMogyRiC-Gyv4CEytvC_KmCLr6ZbFd0WpN8"
    static let sourceCoachDocumentID = "12lJxa9vFAh-ahXp9kRIPu9LQZ8lnOkqBgenuWFSMGWE"
    static let sourceFolderID = "1zO_jsb1U_SDkW2c7Qh5v3EuX6M023XSj"
    static let cycleStart = date(2026, 8, 17)

    static let plan: [WorkoutPlanItem] = [
        warmup(.a, "A-WARMUP", "快走/单车 + 弹力带外旋 + 卧推专项热身", "跑步机/固定单车；弹力带；卧推架+杠铃", "约8分钟", "快走/单车3分钟；外旋2×12–15/侧；空杆×15→30kg×8。若空杆即出现明显深部肩痛，改无痛器械推胸。"),
        strength(.a, 1, "杠铃卧推", "卧推架、奥杆、杠铃片、平板卧推凳", 3, 6, 10, 2, 2, 120...180, "第1周40kg×8×3；肩部稳定后用双进阶，做到10/10/10且RIR≥2再加重量。"),
        strength(.a, 2, "腿举机", "腿举机（45°斜式或坐姿水平式）", 3, 8, 12, 2, 2, 120...180, "第1周选择约第10次还能再做2次的重量；避免憋气和练到恶心想吐。"),
        strength(.a, 3, "高位下拉", "高位下拉机 / 龙门架高位滑轮", 3, 8, 12, 1, 2, 90...120, "第1周可从45kg尝试，根据实际次数和RIR校准。"),
        strength(.a, 4, "器械推肩", "固定式肩推机", 2, 8, 12, 2, 2, 90...90, "仅在明确无痛前提下保留；出现熟悉的肩关节深部疼痛立即停止。"),
        strength(.a, 5, "绳索三头下压", "龙门架 + 绳索把手", 2, 10, 15, 1, 2, 60...90, "达到15/15并保留1–2次余力后再加一个重量档位。"),
        strength(.a, 6, "绳索卷腹", "龙门架 + 绳索把手", 2, 10, 15, 1, 2, 60...60, "胸骨向骨盆卷，作为可渐进负重的腹肌增肌动作。"),
        cardio(.a, "A-CARDIO", "坡度走 / 自行车", "跑步机（坡度走）或固定自行车", "8–10分钟", "呼吸加快但仍能说完整句子，不做HIIT。"),

        warmup(.b, "B-WARMUP", "快走/单车 + 徒手臀桥 + 弹力带外旋 + 胸托划船轻重量", "跑步机/固定单车；训练垫；弹力带；胸托划船机", "约8分钟", "快走/单车3分钟；臀桥1×12；外旋1×12–15/侧；胸托划船轻重量1×15。"),
        strength(.b, 1, "胸托划船", "胸托划船机（器械式优先）", 3, 8, 12, 1, 2, 90...120, "第1周选约10次后还能再做2次的重量；做到12/12/12且稳定后加重量。"),
        strength(.b, 2, "臀推机 / 史密斯臀推", "臀推机；没有则史密斯机+训练凳", 3, 8, 12, 2, 2, 120...120, "第1周保守找重量，顶端停约1秒；避免过度反弓腰。恶心明显上升则延长休息并降负荷/组数。"),
        strength(.b, 3, "上斜器械推胸", "上斜推胸机", 3, 8, 12, 2, 2, 90...120, "选左肩最舒服的握法和座椅高度；疼痛≥3/10或逐组加重时停止并换无痛推胸角度。"),
        strength(.b, 4, "坐姿腿弯举", "坐姿腿弯举机", 2, 10, 15, 1, 2, 90...90, "全程受控；做到15/15且仍有1–2次余力后加重量。"),
        strength(.b, 5, "反向蝴蝶机（后三角）", "反向蝴蝶机 / 反向飞鸟机", 2, 12, 15, 2, 2, 60...90, "只做到肩部舒服的范围；诱发左肩深部疼痛则立即停止。"),
        strength(.b, 6, "绳索弯举", "龙门架 + 绳索把手", 2, 10, 15, 1, 2, 60...90, "肘位置稳定；时间紧张时可与反向蝴蝶机做超级组。"),
        cardio(.b, "B-CARDIO", "坡度走 / 自行车", "跑步机（坡度走）或固定自行车", "8–10分钟", "呼吸加快但仍能说完整句子，不做HIIT。"),

        warmup(.c, "C-WARMUP", "单车/快走 + 髋膝热身 + 肩外旋", "跑步机/固定单车；训练垫；弹力带", "约7–8分钟", "单车/快走3分钟；徒手深蹲或坐立1×10；外旋1×12–15/侧。"),
        strength(.c, 1, "哈克深蹲", "Hack Squat 哈克深蹲机", 3, 8, 12, 2, 2, 120...180, "第一周保守找重量；约10次后还能再做2次。若恶心明显上升，延长休息，必要时3组降为2组。"),
        strength(.c, 2, "辅助引体向上", "辅助引体向上机", 3, 6, 10, 1, 2, 120...120, "先选择能稳定完成6–10次的辅助重量；逐步减少辅助重量。"),
        strength(.c, 3, "平板器械推胸", "固定式平板推胸机", 3, 8, 12, 2, 2, 90...120, "选左肩最舒服的握法/活动范围；疼痛≥3/10或逐组加重则停止并换无痛推胸角度。"),
        strength(.c, 4, "坐姿单腿哑铃提踵", "训练凳、哑铃、杠铃片/踏板", 3, 12, 20, 1, 2, 60...90, "每侧完成；前脚掌垫高，膝盖约90°，哑铃放在同侧大腿靠近膝盖处。底部停1–2秒，顶部收缩1秒，不弹震；三组均达到20次且RIR≥2后增加最小哑铃档位。"),
        strength(.c, 5, "牧师凳弯举 / 器械弯举", "牧师凳弯举机 / 二头弯举机", 2, 10, 15, 1, 2, 60...90, "固定器械优先；达到次数上限且仍有余力后再加重量。"),
        strength(.c, 6, "绳索过头三头伸展", "龙门架 + 绳索把手", 2, 10, 15, 1, 2, 60...90, "上臂稳定；肩部位置不舒服时改回无痛绳索下压。"),
        strength(.c, 7, "反向卷腹 / 悬垂屈膝", "训练垫 / 单杠或悬垂举腿架", 2, 10, 15, 1, 2, 60...60, "重点让骨盆向胸廓方向卷起，不只是抬腿。"),
        cardio(.c, "C-CARDIO", "坡度走 / 自行车", "跑步机（坡度走）或固定自行车", "8–10分钟", "呼吸加快但仍能说完整句子，不做HIIT。")
    ]

    static let configurations: [String: ExerciseConfiguration] = {
        let values: [ExerciseConfiguration] = [
            config("A-01", [.chest], [.triceps, .frontDelts], 2.5, false, true, false, false, 1),
            config("A-02", [.quads], [.glutes], 5, true, false, true, true, 2),
            config("A-03", [.lats], [.upperBack, .biceps], 5, true, false, false, false, 3),
            config("A-04", [.frontDelts], [.triceps, .sideDelts], 5, true, true, false, false, nil),
            config("A-05", [.triceps], [], 5, true, false, false, false, nil),
            config("A-06", [.abs], [], 5, true, false, false, false, nil),
            config("B-01", [.upperBack], [.lats, .rearDelts, .biceps], 5, true, false, false, true, 1),
            config("B-02", [.glutes], [.hamstrings], 5, true, false, true, true, 2),
            config("B-03", [.chest], [.frontDelts, .triceps], 5, true, true, false, false, 3),
            config("B-04", [.hamstrings], [], 5, true, false, false, false, nil),
            config("B-05", [.rearDelts], [.upperBack], 5, true, true, false, false, nil),
            config("B-06", [.biceps], [.forearms], 5, true, false, false, false, nil),
            config("C-01", [.quads], [.glutes], 5, true, false, true, true, 1),
            config("C-02", [.lats], [.upperBack, .biceps], 5, true, false, false, false, 2),
            config("C-03", [.chest], [.frontDelts, .triceps], 5, true, true, false, false, 3),
            config("C-04", [.calves], [], 2.5, false, false, false, false, nil),
            config("C-05", [.biceps], [.forearms], 5, true, false, false, false, nil),
            config("C-06", [.triceps], [.frontDelts], 5, true, true, false, false, nil),
            config("C-07", [.abs], [], nil, false, false, false, false, nil)
        ]
        return Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
    }()

    static let baselineMetrics: [BodyMetric] = [
        BodyMetric(
            id: UUID(uuidString: "8C941C28-567C-4D4F-B8D1-FB9C5B1E0607")!,
            date: date(2026, 6, 7), source: .inBody, weightKG: 73.1, waistCM: nil,
            sleepHours: nil, steps: nil, activeEnergyKCal: nil, exerciseMinutes: nil,
            restingHeartRate: nil, bodyFatPercent: 22.7, skeletalMuscleKG: 31.7,
            fatigueScore: nil, note: "InBody 基线", healthKitSourceIDs: [], updatedAt: date(2026, 6, 7)
        ),
        BodyMetric(
            id: UUID(uuidString: "2A26544F-5145-4480-96C3-BC1B5E5C0817")!,
            date: date(2026, 8, 17), source: .inBody, weightKG: 74.9, waistCM: nil,
            sleepHours: nil, steps: nil, activeEnergyKCal: nil, exerciseMinutes: nil,
            restingHeartRate: nil, bodyFatPercent: 24.2, skeletalMuscleKG: 31.8,
            fatigueScore: nil, note: "InBody 当前基线", healthKitSourceIDs: [], updatedAt: date(2026, 8, 17)
        )
    ]

    static var initialSchedule: ScheduleState {
        .init(nextPlanDay: .a, plannedDate: date(2026, 8, 24), status: .planned, updatedAt: date(2026, 8, 23))
    }

    private static func strength(
        _ day: PlanDay, _ order: Int, _ name: String, _ equipment: String, _ sets: Int,
        _ repMin: Int, _ repMax: Int, _ rirMin: Double, _ rirMax: Double,
        _ rest: ClosedRange<Int>, _ notes: String
    ) -> WorkoutPlanItem {
        WorkoutPlanItem(
            id: "\(day.rawValue)-\(String(format: "%02d", order))", planDay: day, order: order,
            orderLabel: String(order), name: name, equipment: equipment, sets: sets,
            repMin: repMin, repMax: repMax, targetRIRMin: rirMin, targetRIRMax: rirMax,
            restSeconds: rest, notes: notes, kind: .strength
        )
    }

    private static func warmup(
        _ day: PlanDay, _ id: String, _ name: String, _ equipment: String, _ duration: String, _ notes: String
    ) -> WorkoutPlanItem {
        WorkoutPlanItem(
            id: id, planDay: day, order: -1, orderLabel: "热身", name: name, equipment: equipment,
            sets: nil, repMin: nil, repMax: nil, durationText: duration,
            targetRIRMin: nil, targetRIRMax: nil, restSeconds: nil, notes: notes, kind: .warmup
        )
    }

    private static func cardio(
        _ day: PlanDay, _ id: String, _ name: String, _ equipment: String, _ duration: String, _ notes: String
    ) -> WorkoutPlanItem {
        WorkoutPlanItem(
            id: id, planDay: day, order: 99, orderLabel: "有氧", name: name, equipment: equipment,
            sets: nil, repMin: nil, repMax: nil, durationText: duration,
            targetRIRMin: nil, targetRIRMax: nil, restSeconds: nil, notes: notes, kind: .cardio
        )
    }

    private static func config(
        _ id: String, _ primary: Set<MuscleGroup>, _ secondary: Set<MuscleGroup>,
        _ increment: Double?, _ machine: Bool, _ shoulder: Bool, _ nausea: Bool,
        _ lowerBack: Bool, _ quick: Int?
    ) -> ExerciseConfiguration {
        .init(
            id: id, primaryMuscles: primary, secondaryMuscles: secondary,
            excludesMuscleStats: false, increment: increment, machineIncrement: machine,
            tracksShoulderPain: shoulder, tracksNausea: nausea, tracksLowerBack: lowerBack,
            quickPriority: quick, substituteExerciseID: nil
        )
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 8))!
    }
}

enum LegacyPlanParser {
    struct Row: Equatable {
        let day: String
        let order: String
        let exercise: String
        let equipment: String
        let sets: String
        let reps: String
        let rir: String
        let rest: String
        let notes: String
    }

    static func parse(rows: [[String]]) -> [Row] {
        guard let header = rows.first else { return [] }
        let expected = ["日别", "顺序", "动作", "使用器械", "组数", "次数/时长", "RIR", "休息", "说明 / 第一周执行"]
        guard Array(header.prefix(expected.count)) == expected else { return [] }
        return rows.dropFirst().compactMap { row in
            guard row.count >= expected.count else { return nil }
            return Row(
                day: row[0], order: row[1], exercise: row[2], equipment: row[3], sets: row[4],
                reps: row[5], rir: row[6], rest: row[7], notes: row[8]
            )
        }
    }
}
