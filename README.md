# Gradia · iOS 26

个人原生健身记录 App，使用真实 Google A/B/C 计划、SwiftData 离线记录、HealthKit、Google Sheets/Drive 同步，以及基于开源 MuscleMap 的可交互人体肌群统计。

## 本地运行

要求：Xcode 26、iOS 26 SDK、XcodeGen、支持 HealthKit 的付费 Apple Developer Team。

```sh
xcodegen generate
open FitnessApp.xcodeproj
```

在 Xcode 中选择 `FitnessApp` target：

1. Signing & Capabilities 选择自己的付费 Team。
2. 如默认 Bundle ID 已被占用，将 `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER` 改成自己的唯一 ID，然后重新执行 `xcodegen generate`。
3. 先在 iOS 26 模拟器查看 UI，再连接 iPhone 验证 HealthKit 和相机。

命令行验证：

```sh
xcodebuild -project FitnessApp.xcodeproj -scheme FitnessApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  CODE_SIGNING_ALLOWED=NO test
```

## 数据边界

- Google Sheets：训练计划、训练组、排期、手工指标和 Coach 建议的业务主库。
- HealthKit：Apple 健康原始样本和外部训练的权威来源。
- Google Drive：餐食照片原文件。
- SwiftData：离线镜像和待同步队列。

现有 `训练计划` tab 保持原样。App 内置的初始计划来自正式 Google Sheet 的 25 条记录，并保存源文件 ID；部署 Apps Script 后可通过兼容层更新。

## 功能

- 今天：下一次训练、HealthKit 恢复摘要、晨重/腰围/饮食快捷记录。
- 训练：逐组重量/次数/RIR、休息计时和症状评分。
- 动作指南：19 个计划动作提供动态示范、中文步骤、目标肌群和个人训练提示。
- 训练草稿：SwiftData 每 2 秒自动保存，杀进程或断网后仍可继续；完成或明确丢弃后清除。
- 历史：月历、A/B/C、总容量和单次训练明细。
- 统计：15 肌群正反面人体热力图、加权有效组、训练与体重趋势。
- 更多：训练计划、Apple 健康、数据备份与关于 Gradia。

Google 后端部署见 `backend/apps-script/README.md`。

## 验收结果

- iPhone 17 Pro / iOS 26.0 模拟器已验证首页、历史/统计切换、人体肌群点击详情、深浅色和 VoiceOver 描述。
- 自动化测试共 18 项，覆盖真实 25 行计划、19 个动作指南映射、九列兼容解析、加重安全门、HealthKit、同步策略、肌群计数排除规则、周均色阶与排期。
- 已实测输入训练组后强制结束 App，重启后重量、次数和 RIR 均由 SwiftData 草稿恢复。

验收截图位于 `docs/screenshots/`。
