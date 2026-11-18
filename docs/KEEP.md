# Keep connection / Keep 接入

Poise 0.8.0 adds a separate, optional read-only Keep connection through Keep's MCP gateway. This is independent of Health Connect and HealthKit.

## 使用

1. 更新到 0.8.2，打开设置 → 数据来源 → Keep 身体记录。
2. 点击“授权连接 Keep”。Poise 先检测本机是否安装 Keep，已安装就直接打开 Keep 内的授权页面，不展示二维码。确认后返回 Poise；授权会话约 5 分钟有效。未安装时提示先安装并登录 Keep，唤起失败时可更新 Keep 后重试。
3. 在 Keep 中确认授权后需手动返回 Poise（当前授权页面没有第三方回跳回调）。授权后读取并弹出底部预览面板。后续会从设备安全存储恢复登录，不需要每次授权；Keep 撤销或登录过期后需重新授权。
4. 可选择近 7 / 30 / 90 / 365 天，读取体重、体脂率和最新身高、BMI。先核对面板内预览及“Keep 返回内容”，再点击底部固定的确认导入按钮；关闭面板不保存，可通过“查看读取结果”重新打开。保存成功后显示成功提示及记录天数。
5. 身高默认不覆盖身体档案；勾选“使用 Keep 身高更新身体档案”后才更新，并影响历史 BMI 计算。

## Connect on this device

In 0.8.1, Settings → Keep body journal → Authorize Keep checks for the installed Keep app and opens its authorization page directly. No QR image is displayed. Confirm in Keep, then return to Poise. If Keep is missing, install it and sign in first; if handoff fails, update Keep and retry. You can reopen Keep while authorization is pending. The official app artwork identifies this integration.

The route follows Keep’s own public authorization page: `keep://webview/<percent-encoded HTTPS authorization URL>?isExternalLaunch=1`. Android checks and explicitly targets `com.gotokeep.keep`; iOS queries the `keep` URL scheme. Only `https://show.gotokeep.com/login/auth` is accepted as a handoff target. Reference: [Keep authorization page](https://show.gotokeep.com/login/auth) and its published `loginAuth-460974dea6.js` script, checked 2026-11-18. Installation detection uses platform app visibility, not broad package access. The gateway still issues its login session through `get_qrcode`, but the QR image is never fetched or rendered by Poise.

## 数据精度与限制

- 当前网关通过 `query_tool` 返回文本，包含日期和值，不提供原始记录 ID 和测量时分秒。本功能只导入能严格识别且处于选定范围内的日期明细，不推算或补全数值。
- 请求时间范围不代表上游一定返回完整历史；此版本不承诺全量 Keep 历史导出。格式变化或不识别的结果会提示用户检查，不会伪装成成功导入。
- Keep 导入数据以账号哈希 + 日期为本地更新键。这是 Poise 自己的去重键，不是 Keep 的原始记录 ID。重复读取更新相同日值；未返回字段保留原副本，未返回日期不会自动删除。
- 同一天同一指标出现不同数值时，不自行挑选，跳过该日该项并提示核对。
- 日期记录只显示在“全天”，显示“仅日期”，不归入早上/下午/晚上，不显示假造的 00:00 测量时间。内部按日期分组使用的 DateTime 不表示上游提供了时间。
- 同日同时有精确时间和 Keep 日期值时，主趋势优先使用有精确测量时间的记录。独立体脂日值也能进入体脂趋势。
- Keep 最新身高和 BMI 没有记录日期，单独展示，不绑定到某一天的测量。主图 BMI 仍按 Poise 当前身高计算。
- Keep 记录在主界面只读。到 Keep 修改后重新读取，或在连接页移除本地 Keep 副本；手动、Fitdays 和系统健康数据互不删除。
- 本版本 Keep 为手动读取、预览、导入，不加入打开 App 自动同步；原系统健康自动同步继续工作。

## Privacy and storage

- MCP endpoint: `https://mcp.gotokeep.com/skills-mcp-gateway-page/v1`.
- The client invokes only initialization, QR authorization, login status, `query_tool`, and optional `revoke_auth`. It never invokes Keep record or upload tools.
- Authentication and fixed date-range queries go directly to Keep over HTTPS; Poise does not forward other health records to Keep or an application server.
- Login credentials are stored with Android encrypted preferences / Keystore and iOS Keychain via `flutter_secure_storage`. They are excluded from measurement JSON and source control. Android automatic application backup is disabled to avoid restoring encrypted login storage without its key.
- Disconnect revokes the Keep token when possible, clears local login storage, and keeps imported records. If remote revocation fails, the UI reports this while still clearing local login information.
- JSON schema 3 includes `keepSamples` with dates, values and account hashes. Schema 1 and 2 backups remain readable. Older Poise versions cannot read schema 3; keep an original backup before downgrading.

## Import preview

In 0.8.2, reading opens a bottom sheet. Preview content scrolls while the confirmation button stays visible. Closing the sheet does not save data; View results reopens it. Successful saves close the preview and show an Import successful dialog with the number of days. Failed saves keep the preview open for retry. Confirm in Keep, then manually return to Poise; this Keep authorization flow does not expose a third-party return callback.

## Validation

Synthetic tests cover daily parsing, unsupported formats, conflicting values, invalid ranges, same-account/day updates, multiple accounts, date precision and source precedence, fat-only trends, old/new backup versions, MCP SSE session headers, read-only tool calls, expired credentials, URL validation, explicit preview/commit, optional height update, cancelled authorization, failure preservation, bilingual UI, and small-screen calendar stability.

Public endpoint metadata and the daily line format were verified against the live service during development. Personal account responses were used only for private verification and are not included in source, tests, website screenshots or published artifacts. Native app handoff / return-to-app behavior and encrypted storage still need real-device acceptance. iOS source is configured; this Linux workspace does not produce an IPA.
