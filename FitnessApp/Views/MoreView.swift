import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthKit: HealthKitService

    var body: some View {
        NavigationStack {
            List {
                Section("训练") {
                    NavigationLink {
                        WorkoutPlanDetailView()
                    } label: {
                        SettingsRow(
                            icon: "list.clipboard.fill",
                            title: "训练计划",
                            subtitle: "下一次 \(store.schedule.nextPlanDay.rawValue) 日 · \(store.schedule.nextPlanDay.focus)"
                        )
                    }
                }

                Section("健康与备份") {
                    Button {
                        Task {
                            await healthKit.requestAuthorization()
                            let summary = await healthKit.fetchTodaySummary()
                            store.importHealthSummary(summary)
                            if let changes = try? await healthKit.fetchWorkoutChanges() {
                                store.importHealthWorkoutChanges(changes)
                            }
                        }
                    } label: {
                        HStack {
                            SettingsRow(
                                icon: "heart.fill",
                                title: "Apple 健康",
                                subtitle: healthKitSubtitle
                            )
                            Spacer()
                            Image(systemName: healthKit.isAuthorized ? "checkmark.circle.fill" : "chevron.right")
                                .foregroundStyle(healthKit.isAuthorized ? Color.primary : Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        GoogleSyncSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "icloud.fill",
                            title: "数据备份",
                            subtitle: backupSubtitle
                        )
                    }
                }

                Section {
                    NavigationLink {
                        AboutGradiaView()
                    } label: {
                        SettingsRow(
                            icon: "info.circle.fill",
                            title: "关于 Gradia",
                            subtitle: "版本、隐私与开源致谢"
                        )
                    }
                }
            }
            .navigationTitle("更多")
        }
    }

    private var healthKitSubtitle: String {
        if let error = healthKit.lastError { return error }
        if healthKit.isAuthorized {
            if store.healthSummary.sleepHours == nil && store.healthSummary.restingHeartRate == nil {
                return "尚未读到睡眠或心率，点按重新检查"
            }
            return "已连接，自动更新身体与恢复数据"
        }
        return "同步步数、睡眠、心率和训练"
    }

    private var backupSubtitle: String {
        switch store.syncState {
        case .syncing: store.syncMessage
        case .synced: "已自动备份"
        case .failed: "备份失败，点按查看原因"
        case .local:
            if store.pendingCount > 0 && store.isGoogleSyncConfigured {
                "\(store.pendingCount) 条记录等待备份"
            } else if store.isGoogleSyncConfigured {
                "已开启自动备份"
            } else {
                "保存训练记录，换设备也能恢复"
            }
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct WorkoutPlanDetailView: View {
    @EnvironmentObject private var store: AppStore
    @State private var day: PlanDay = .a

    var body: some View {
        List {
            Picker("日别", selection: $day) {
                ForEach(PlanDay.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            Section("\(day.rawValue) 日 · \(day.focus)") {
                ForEach(store.workoutPlan.filter { $0.planDay == day }) { item in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(item.orderLabel) · \(item.name)").font(.headline)
                            Text(item.equipment).font(.caption).foregroundStyle(.secondary)
                            Text(item.notes).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        ExerciseGuideButton(
                            item: item,
                            configuration: store.exerciseConfigurations[item.id],
                            compact: true
                        )
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Link("在 Google 表格中查看计划", destination: URL(string: "https://docs.google.com/spreadsheets/d/\(SeedData.sourceSpreadsheetID)/edit")!)
            } footer: {
                Text("需要直接调整训练安排时，可以打开你的原始计划表。")
            }
        }
        .navigationTitle("训练计划")
    }
}

private struct AboutGradiaView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 72, height: 72)
                        .background(Color.primary.gradient, in: RoundedRectangle(cornerRadius: 20))
                    Text("Gradia")
                        .font(.title2.bold())
                    Text("专注记录训练、恢复与身体变化")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }

            Section("应用") {
                LabeledContent("版本", value: versionText)
                Text("你的记录优先保存在本机；Apple 健康数据仍由 Apple 健康管理。开启数据备份后，训练和身体记录会保存到你的私人 Google 表格。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("开源致谢") {
                Link(
                    "MuscleMap · 人体肌群图",
                    destination: URL(string: "https://github.com/melihcolpan/MuscleMap")!
                )
                Link(
                    "Exercises Dataset · 动作说明",
                    destination: ExerciseGuideCatalog.repositoryURL
                )
                Link(
                    "Gym visual · 演示素材来源",
                    destination: ExerciseGuideCatalog.mediaAttributionURL
                )
                Text("动作文字与数据采用 MIT 许可；180 × 180 动态演示仅在个人原型中从原仓库加载，素材版权归 Gym visual。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于 Gradia")
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

private struct GoogleSyncSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var endpoint = UserDefaults.standard.string(forKey: "googleEndpoint") ?? ""
    @State private var token = KeychainStore.read(service: "FitnessApp", account: "googleToken") ?? ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Label("自动备份训练、身体记录和餐食照片", systemImage: "lock.icloud.fill")
                    .foregroundStyle(.primary)
            } footer: {
                Text("数据只会保存到你自己的 Google 账号。设置一次后，Gradia 会在产生新记录时自动备份。")
            }

            Section("连接信息") {
                TextField("同步服务地址", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("访问密钥", text: $token)
                    .textInputAutocapitalization(.never)
            }

            Section {
                Button("保存并立即备份") {
                    if save(showMessage: false) {
                        message = nil
                        Task { await store.syncNow() }
                    }
                }
                .disabled(endpoint.isEmpty || token.isEmpty)
            }

            Section("备份状态") {
                LabeledContent("等待备份", value: "\(store.pendingCount) 条")
                LabeledContent("当前状态", value: message ?? friendlySyncStatus)
                if let lastSyncAt = store.lastSyncAt {
                    LabeledContent(
                        "上次备份",
                        value: lastSyncAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        }
        .navigationTitle("数据备份")
    }

    private var friendlySyncStatus: String {
        switch store.syncState {
        case .synced: "已完成"
        case .syncing, .failed: store.syncMessage
        case .local: store.isGoogleSyncConfigured ? "等待自动备份" : "尚未设置"
        }
    }

    @discardableResult
    private func save(showMessage: Bool = true) -> Bool {
        let cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: cleanEndpoint),
              url.scheme == "https", cleanEndpoint.hasSuffix("/exec") else {
            message = "请输入有效的 Web App 地址"
            return false
        }
        guard !cleanToken.isEmpty else {
            message = "请输入访问密钥"
            return false
        }
        endpoint = cleanEndpoint
        token = cleanToken
        UserDefaults.standard.set(cleanEndpoint, forKey: "googleEndpoint")
        do {
            try KeychainStore.save(cleanToken, service: "FitnessApp", account: "googleToken")
            if showMessage { message = "配置已保存" }
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }
}
