import MuscleMap
import SwiftUI

/// MuscleMap renders the anatomy; Gradia remains responsible for calculating
/// weighted effective sets and translating them into the five display levels.
struct MuscleMapView: View {
    let contributions: [MuscleContribution]
    let period: StatisticsPeriod
    @Binding var selectedMuscle: MuscleGroup?

    private var values: [MuscleGroup: Double] {
        Dictionary(uniqueKeysWithValues: contributions.map { ($0.id, $0.weightedSets) })
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            body(side: .front, title: "正面")
            body(side: .back, title: "背面")
        }
        .frame(height: 330)
        .accessibilityElement(children: .contain)
    }

    private func body(side: BodySide, title: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            BodyView(gender: .male, side: side, style: Self.bodyStyle)
                .showSubGroups()
                .heatmap(heatmapData)
                .selected(selectedSDKMuscles)
                .animated(duration: 0.28)
                .onMuscleSelected { muscle, _ in
                    if let group = MuscleMapAdapter.appMuscle(for: muscle) {
                        selectedMuscle = group
                    }
                }
                .accessibilityLabel("人体肌群\(title)图")
        }
    }

    private var heatmapData: [MuscleIntensity] {
        MuscleGroup.allCases.flatMap { group -> [MuscleIntensity] in
            let level = MuscleStatsCalculator.intensityLevel(for: values[group, default: 0])
            let color = AppTheme.muscleScale[level]
            return MuscleMapAdapter.sdkMuscles(for: group).map {
                MuscleIntensity(muscle: $0, intensity: Double(level) / 4, color: color)
            }
        }
    }

    private var selectedSDKMuscles: Set<Muscle> {
        guard let selectedMuscle else { return [] }
        return Set(MuscleMapAdapter.sdkMuscles(for: selectedMuscle))
    }

    private static let bodyStyle = BodyViewStyle(
        defaultFillColor: Color.secondary.opacity(0.08),
        strokeColor: Color.secondary.opacity(0.24),
        strokeWidth: 0.65,
        selectionColor: .orange,
        selectionStrokeColor: .orange,
        selectionStrokeWidth: 2,
        headColor: Color.secondary.opacity(0.10),
        hairColor: Color.primary.opacity(0.72)
    )
}

enum MuscleMapAdapter {
    /// MuscleMap 1.6.4 has no dedicated latissimus or lateral-deltoid enum.
    /// `upperBack` covers the lateral back surface; base `deltoids` covers the
    /// lateral shoulder around the front/rear deltoid sub-groups.
    static func sdkMuscles(for group: MuscleGroup) -> [Muscle] {
        switch group {
        case .chest: [.chest]
        case .frontDelts: [.frontDeltoid]
        case .sideDelts: [.deltoids]
        case .rearDelts: [.rearDeltoid]
        case .lats: [.upperBack]
        case .upperBack: [.trapezius, .rhomboids]
        case .biceps: [.biceps]
        case .triceps: [.triceps]
        case .forearms: [.forearm]
        case .abs: [.abs]
        case .lowerBack: [.lowerBack]
        case .glutes: [.gluteal]
        case .quads: [.quadriceps]
        case .hamstrings: [.hamstring]
        case .calves: [.calves]
        }
    }

    static func appMuscle(for muscle: Muscle) -> MuscleGroup? {
        switch muscle {
        case .chest, .upperChest, .lowerChest: .chest
        case .frontDeltoid: .frontDelts
        case .deltoids: .sideDelts
        case .rearDeltoid, .rotatorCuff: .rearDelts
        case .upperBack: .lats
        case .trapezius, .upperTrapezius, .lowerTrapezius, .rhomboids: .upperBack
        case .biceps: .biceps
        case .triceps: .triceps
        case .forearm, .hands: .forearms
        case .abs, .upperAbs, .lowerAbs, .obliques, .serratus: .abs
        case .lowerBack: .lowerBack
        case .gluteal: .glutes
        case .quadriceps, .innerQuad, .outerQuad, .hipFlexors, .knees: .quads
        case .hamstring, .adductors: .hamstrings
        case .calves, .tibialis, .ankles, .feet: .calves
        case .head, .neck: nil
        }
    }
}
