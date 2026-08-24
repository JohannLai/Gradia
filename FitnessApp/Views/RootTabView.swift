import SwiftData
import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            Tab("今天", systemImage: "sun.max.fill", value: 0) {
                TodayView(selectedTab: $selection)
            }
            Tab("训练", systemImage: "dumbbell.fill", value: 1) {
                TrainingHomeView()
            }
            Tab("数据", systemImage: "chart.xyaxis.line", value: 2) {
                DataHubView()
            }
            Tab("更多", systemImage: "ellipsis", value: 3) {
                MoreView()
            }
        }
        .tint(.primary)
        .scrollDismissesKeyboard(.interactively)
        .background {
            KeyboardDismissInstaller()
                .frame(width: 0, height: 0)
        }
        .task {
            if store.activeDraft != nil { selection = 1 }
        }
        .onChange(of: store.activeDraft?.id) { _, activeDraftID in
            if activeDraftID != nil { selection = 1 }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: LocalRecord.self, PendingMutation.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    RootTabView()
        .environmentObject(AppStore(context: container.mainContext))
        .environmentObject(HealthKitService())
}
