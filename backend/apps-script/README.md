# Google Apps Script 部署

该脚本以现有 Spreadsheet `健身计划与进度追踪｜12周` 为目标，不修改原有 `训练计划` tab。

1. 在 Google Apps Script 新建独立项目，将 `Code.gs` 和 `appsscript.json` 复制进去。
2. 项目设置中确认时区为 `Asia/Shanghai`。
3. 运行 `setupSchema()`。首次运行会在原 Drive 文件夹创建带时间戳的完整备份，再添加 App 所需 tabs；任何已存在 tab 的标题不匹配时会停止，不覆盖数据。
4. 运行 `createPersonalToken()`，复制返回的令牌。令牌写入 Script Properties 的 `API_TOKEN`，不要提交到仓库。
5. 部署为 Web App：执行身份选择“我”，访问范围选择“任何人”。接口自身仍会验证 JSON body 中的个人令牌。
6. 把 `/exec` 地址和令牌填入 iOS App 的“更多 → 数据备份”。令牌只保存在设备 Keychain。

更新 `Code.gs` 后，在“部署 → 管理部署 → 编辑”中选择“新版本”并重新部署。保留同一个部署时，App 中的 `/exec` 地址无需更换。客户端通过 `syncBatch` 每批提交最多 25 个非照片 mutation，服务端逐项返回成功或错误；HealthKit 日汇总在同一次 Sheet 批量写入中完成。照片保持独立上传，并按 `photo_id` 去重。

可选 Script Properties：

- `SPREADSHEET_ID`：覆盖默认正式表 ID。
- `SOURCE_FOLDER_ID`：覆盖照片目录的父文件夹。
- `MEAL_FOLDER_ID`：脚本首次上传照片后自动写入。

所有写请求都带 `requestId`。已处理的 ID 会记录在 `SchemaMeta`，重复请求返回成功但不会重复追加训练或推进 A/B/C。
