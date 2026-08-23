import SwiftData
import SwiftUI

@main
struct FitnessLogApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer
    @StateObject private var store: AppStore
    @StateObject private var healthKit = HealthKitService()

    init() {
        do {
            let container = try ModelContainer(for: LocalRecord.self, PendingMutation.self)
            modelContainer = container
            _store = StateObject(wrappedValue: AppStore(context: container.mainContext))
        } catch {
            fatalError("无法初始化本地数据库：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(healthKit)
                .task {
                    await healthKit.requestAuthorization()
                    await refreshHealthData()
                    await store.syncNow(force: false)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await refreshHealthData()
                        await store.syncNow(force: false)
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    private func refreshHealthData() async {
        let summary = await healthKit.fetchTodaySummary()
        store.importHealthSummary(summary)
        if let changes = try? await healthKit.fetchWorkoutChanges() {
            store.importHealthWorkoutChanges(changes)
        }
    }
}
