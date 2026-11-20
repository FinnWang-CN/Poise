// UI catalog. Imported field keys and stored measurements remain unchanged.
const translations = <String, String>{
  "数据对比": "Compare records",
  "基准记录": "Baseline",
  "对比记录": "Comparison",
  "选择基准记录": "Choose baseline",
  "选择对比记录": "Choose comparison",
  "选择记录": "Choose a record",
  "点击更换": "Tap to change",
  "交换记录": "Swap records",
  "已用于另一组": "Selected on the other side",
  "上一个有记录的日期": "Previous recorded date",
  "下一个有记录的日期": "Next recorded date",
  "文件导入": "File import",
  "手动记录": "Manual entry",
  "百分点": "pp",
  "相隔 {0} 天": "{0} days apart",
  "至少需要两条体重记录才能对比。": "At least two weight records are needed to compare.",
  "差值 = 对比记录 − 基准记录。缺失或单位不同的指标不计算差值；增减不代表健康评价。BMI 优先使用原始值，否则按当前身高计算。":
      "Change = comparison minus baseline. No change is calculated for missing values or incompatible units. Increases and decreases are not health ratings. BMI uses the original value when available, otherwise your current height.",

  "支持 Poise": "Support Poise",
  "赞赏作者": "Support the author",
  "感谢你的支持": "Thank you for your support",
  "感谢你支持 Poise 的持续开发。":
      "Thank you for supporting the continued development of Poise.",
  "Finn Wang 的微信赞赏码": "Finn Wang's WeChat appreciation code",
  "可截图后在微信扫一扫中从相册识别。赞赏完全自愿，不影响任何功能。":
      "Take a screenshot and select it from your album in WeChat Scan. Support is optional and does not affect any features.",

  "完成": "Done",
  "导入成功": "Import successful",
  "{0} 天 Keep 数据已保存到 Poise。": "{0} days of Keep data saved to Poise.",
  "查看读取结果": "View results",
  "未检测到 Keep，请先安装 Keep 并登录后重试。":
      "Keep was not found. Install Keep and sign in, then retry.",
  "无法唤起 Keep，请确认已安装最新版本后重试。":
      "Could not open Keep. Check that the latest Keep app is installed, then retry.",
  "Keep 授权链接无效，请重新连接。": "Invalid Keep authorization link. Please reconnect.",
  "请在 Keep 中确认授权，然后返回 Poise。":
      "Confirm authorization in Keep, then return to Poise.",
  "Keep 授权已超时，请重新连接。": "Keep authorization timed out. Please reconnect.",
  "重新打开 Keep": "Reopen Keep",
  "设备安全存储不可用，请检查系统后重试。":
      "Device secure storage is unavailable. Check your system and retry.",
  "Keep 身体记录": "Keep body journal",
  "连接已有数据，接着记录变化。": "Bring your existing measurements along.",
  "授权读取体重、体脂与身体档案": "Connect weight, body fat and profile",
  "连接 Keep": "Connect Keep",
  "Keep 登录信息无效，请重新连接。": "Invalid Keep login. Please reconnect.",
  "Keep 授权已失效，请重新连接。": "Keep access has expired. Please reconnect.",
  "Keep 服务暂不可用，请稍后重试。": "Keep is temporarily unavailable. Try again later.",
  "Keep 返回错误，请重新连接后重试。": "Keep returned an error. Reconnect and try again.",
  "Keep 返回格式有变化，请稍后重试。":
      "The Keep response format has changed. Try again later.",
  "Keep 请求失败或授权已失效，请重新连接后重试。":
      "The Keep request failed or access expired. Reconnect and try again.",
  "无法获取 Keep 授权会话，请重试。": "Could not start Keep authorization. Please retry.",
  "读取范围无效。": "Invalid date range.",
  "已跳过无效或超出读取范围的 Keep 数据。": "Skipped invalid or out-of-range Keep data.",
  "未识别体脂率明细，请检查 Keep 返回内容。":
      "Could not recognize body fat entries. Check the Keep response.",
  "未识别体重明细，请检查 Keep 返回内容。":
      "Could not recognize weight entries. Check the Keep response.",
  "同一天存在不同数值，已跳过该日该项，请在 Keep 中核对。":
      "Conflicting values on the same day were skipped. Check them in Keep.",
  "连接 Keep 失败，请检查网络后重试。":
      "Could not connect to Keep. Check your network and retry.",
  "正在连接 Keep…": "Connecting to Keep…",
  "Keep 连接成功。": "Connected to Keep.",
  "已取消 Keep 连接。": "Keep connection cancelled.",
  "正在读取 Keep 数据…": "Reading Keep data…",
  "未读到可导入的日期记录。": "No dated entries available to import.",
  "读取完成，请核对后导入。": "Ready. Review the results before importing.",
  "Keep 数据已导入，重复读取不会新增相同日期记录。":
      "Keep data imported. Reading again updates the same daily entries.",
  "已断开 Keep 连接，已导入记录保留。": "Disconnected from Keep. Imported entries are kept.",
  "本机登录信息已清除，Keep 远端撤销失败。":
      "Local login cleared. Keep could not revoke remote access.",
  "移除 Keep 数据副本？": "Remove local Keep copies?",
  "只移除 Poise 内的 Keep 记录，手动记录、健康数据和 Keep 原始记录均保留。":
      "Only removes Keep entries in Poise. Manual entries, system health data and original Keep records remain.",
  "Keep 本地副本已移除。": "Local Keep copies removed.",
  "读取结果": "Results",
  "{0} 天记录 · 体重 {1} 天 · 体脂 {2} 天": "{0} days · Weight: {1} · Body fat: {2}",
  "Keep 最新身高：{0} cm": "Latest Keep height: {0} cm",
  "Keep BMI：{0}": "Keep BMI: {0}",
  "身高和 Keep BMI 未提供记录日期，仅展示最新查询值，不作为历史测量。":
      "Height and Keep BMI have no measurement date. These are the latest queried values, not historical measurements.",
  "使用 Keep 身高更新身体档案": "Use Keep height in my profile",
  "更新身高会重新计算历史 BMI。": "Updating height recalculates historical BMI.",
  "预览仅显示前 5 天，确认后导入全部已识别记录。":
      "Preview shows the first 5 days. Confirm to import all recognized entries.",
  "已导入": "Imported",
  "查看 Keep 返回内容": "View the Keep response",
  "读取 Keep 的体重、体脂及最新身高和 BMI。只有确认导入后才会写入 Poise，Keep 原始记录不会修改。":
      "Read Keep weight, body fat and the latest height and BMI. Data is saved in Poise only after you confirm. Original Keep records are never modified.",
  "Keep 连接仅支持 Android / iOS 原生 App，网页预览不支持。":
      "Keep connection is available in the Android / iOS app, not the web preview.",
  "授权已过期，请重新连接。": "Access expired. Please reconnect.",
  "已连接 Keep": "Connected to Keep",
  "断开连接": "Disconnect",
  "授权连接 Keep": "Authorize Keep",
  "取消连接": "Cancel connection",
  "读取 Keep 数据": "Read Keep data",
  "重新授权": "Authorize again",
  "已保存 {0} 天 Keep 数据": "{0} days of Keep data saved",
  "移除 Keep 本地副本": "Remove local Keep copies",
  "Keep 数据说明": "About Keep data",
  "Keep 当前只返回日期和数值，不提供测量时分秒及原始 ID。Poise 按账号和日期更新 Keep 每日值，日期记录仅显示在“全天”，不会伪造测量时间。同日有精确时间的其他来源记录优先用于主趋势。":
      "Keep currently returns dates and values, without precise times or original IDs. Poise updates daily values by account and date. Date-only entries appear under All day, without invented times. Timed entries from other sources take priority for the main daily trend.",
  "登录凭据由设备安全存储保存，不进入 JSON 备份。连接时仅向 Keep 发送授权和查询请求，不上传你的其他健康记录。此版本暂不自动同步 Keep；读取结果需核对后导入。":
      "Login credentials use device secure storage and are excluded from JSON backups. Only authorization and query requests are sent to Keep, never your other health records. This version does not auto-sync Keep; review results before importing.",
  "仅日期": "Date only",
  "Keep · 日期记录": "Keep · Date-only entry",
  "Keep 记录": "Keep entry",
  "体脂率 {0}%": "Body fat {0}%",
  "Keep 仅提供日期，未提供测量时间。在 Keep 中修改后，可重新读取并更新此处记录。":
      "Keep provides a date without a measurement time. Edit in Keep, then read again to update this entry.",
  "本地 {0} 条 · 健康 {1} 条 · Keep {2} 天":
      "Local: {0} · Health: {1} · Keep: {2} days",
  "导入 {0} 条手动记录、{1} 条健康数据和 {2} 天 Keep 数据，替换当前全部记录和设置。请先备份现有数据。":
      "Import {0} manual entries, {1} health samples and {2} days from Keep, replacing current records and profile settings. Back up existing data first.",
  "导入记录保存在当前设备。连接 Keep 时会向 Keep 发送授权和查询请求，不上传你的其他健康记录；登录凭据不进入 JSON 备份。卸载或清理数据可能丢失记录，请定期备份。智能秤直连尚未接入。":
      "Imported entries stay on this device. Connecting to Keep sends authorization and query requests to Keep, never your other health records. Login credentials are excluded from JSON backups. Uninstalling or clearing data may erase entries; back up regularly. Direct smart-scale connections are not yet available.",
  "Keep 日期记录不含测量时间；同日有精确时间的记录优先，缺测不补零。":
      "Keep date-only entries have no measurement time. Timed entries take priority on the same day. Missing days are not filled with zero.",

  "偏好设置": "Preferences",
  "此操作无法撤销，并会关闭自动同步。建议先导出备份；身高和目标设置会保留，系统健康原始记录不会删除。":
      "This cannot be undone and turns off auto-sync. Export a backup first. Height and goal settings remain; original system health records are not deleted.",
  "授权后可在打开 App 时自动同步，不会修改系统健康记录。":
      "After authorization, health data can sync when you open the app. System records are never modified.",
  "打开 App 自动同步": "Sync when opening the app",
  "首次需点“授权并读取”；之后启动或回到 App 时按上次范围同步，不会再次弹出授权。":
      "Tap Authorize and read once. Then sync the same range when opening or returning to the app, without permission prompts.",
  "自动同步设置读取失败，请重新打开页面。": "Could not load auto-sync settings. Reopen this page.",
  "自动同步设置保存失败，请重试。": "Could not save auto-sync settings. Please retry.",
  "移除本地健康数据并关闭自动同步。手动记录和系统原始数据会保留，需要时可重新导入。":
      "Remove local health copies and turn off auto-sync. Manual entries and original system data remain. You can import again later.",
  "• 开启自动同步后，启动或回到 App 时读取上次选择的范围；可用上方开关关闭。":
      "• Auto-sync reads the last selected range when opening or returning to the app. Turn it off with the switch above.",
  "{0} 斤": "{0} jin",
  "{0} 岁": "{0} years",
  "{0}（系统记录）": "{0} (system entry)",
  "演示数据 · 第二次测量": "Demo data · Second measurement",
  "轻衡": "Poise",
  "轻衡 · 身体记录": "Poise · Body Journal",
  "轻衡 0.8.6 · 身体记录": "Poise 0.8.6 · Body Journal",
  "日历": "Calendar",
  "趋势": "Trends",
  "设置": "Settings",
  "全天": "All day",
  "早上": "Morning",
  "下午": "Afternoon",
  "晚上": "Evening",
  "中文": "中文",
  "外观": "Appearance",
  "语言": "Language",
  "浅色": "Light",
  "深色": "Dark",
  "跟随系统": "System",
  "外观设置保存失败，请重试": "Could not save appearance. Please try again.",
  "语言设置保存失败，请重试": "Could not save language. Please try again.",
  "身体日历": "Body calendar",
  "每一次记录，都是对自己的关照。": "Every entry is a moment of self-care.",
  "上个月": "Previous month",
  "下个月": "Next month",
  "今天": "Today",
  "{0} 年 {1} 月": "{0}/{1}",
  "日": "Sun",
  "一": "Mon",
  "二": "Tue",
  "三": "Wed",
  "四": "Thu",
  "五": "Fri",
  "六": "Sat",
  "记一笔": "Add entry",
  "你的身体记录": "Your body journal",
  "记录变化，慢慢靠近目标。": "Track your changes, one day at a time.",
  "取消": "Cancel",
  "确认": "Confirm",
  "关闭": "Close",
  "保存": "Save",
  "删除": "Delete",
  "导入": "Import",
  "移除": "Remove",
  "重新读取": "Retry",
  "本地数据读取失败。为保护原始数据，已暂停写入，请重试。":
      "Could not load local data. Saving is paused to protect your records. Please retry.",
  "保存失败，请检查设备存储后重试": "Could not save. Check device storage and try again.",
  "这一天还没有记录": "No entries for this day",
  "点击顶部“记一笔”添加记录": "Tap “Add entry” above to get started",
  "第 {0} 条，共 {1} 条。左右滑动切换。": "Entry {0} of {1}. Swipe left or right.",
  "{0} 次记录，{1}": "{0} entries, {1}",
  "{0} 次记录 · {1}": "{0} entries · {1}",
  "{0} · 全天": "{0} · All day",
  "{0} · 早上": "{0} · Morning",
  "{0} · 下午": "{0} · Afternoon",
  "{0} · 晚上": "{0} · Evening",
  "体重": "Weight",
  "体脂率": "Body fat",
  "身高": "Height",
  "斤": "jin",
  "岁": "years",
  "体重 {0}": "Weight {0}",
  "体脂率 %": "Body fat %",
  "变化趋势": "Trends",
  "关注长期变化，也接纳日常波动。": "See the bigger picture, embrace daily changes.",
  "更多身体指标": "More body metrics",
  "选择表格中的其他指标": "Choose an imported metric",
  "BMI（文件原值）": "BMI (imported)",
  "近一年": "1 year",
  "近 {0} 天": "{0} days",
  "最近 {0} 天": "Last {0} days",
  "最近记录": "Latest",
  "较区间首次": "Change",
  "记录天数": "Days logged",
  "这个区间还没有数据": "No data in this period",
  "填写体脂率后，就能在这里看见趋势。": "Add body fat measurements to see your trend.",
  "添加记录后，变化会在这里呈现。": "Add entries to see your progress here.",
  "按所选指标每天最后一次有效记录显示，缺测不补零。":
      "Shows the last valid reading each day. Missing days are not filled with zero.",
  "橙色虚线：目标 {0} {1}": "Orange dashed line: goal {0} {1}",
  "BMI 按当前身高 {0} cm 计算": "BMI uses your current height of {0} cm",
  "体脂率仅使用已填写的数据": "Body fat uses recorded values only",
  "测量记录": "Measurements",
  "趋势取每天最后一次测量，缺测不补零。":
      "Trends use the last reading each day. Missing days are not filled with zero.",
  "系统记录": "System entry",
  "编辑记录": "Edit entry",
  "个人设置": "Settings",
  "让记录更适合你的日常。": "Make your journal feel like you.",
  "数据来源": "Data sources",
  "导入 Fitdays 文件": "Import Fitdays file",
  "Excel 历史记录与全部指标": "Excel history and all metrics",
  "健康数据": "Health data",
  "身体档案": "Body profile",
  "身高与目标体重": "Height and goal weight",
  "使用斤显示": "Display weight in jin",
  "内部统一以公斤保存": "Stored internally in kilograms",
  "数据备份": "Backup",
  "导出 JSON 备份": "Export JSON backup",
  "本地 {0} 条 · 健康 {1} 条": "Local: {0} · Health: {1}",
  "导入 JSON 备份": "Import JSON backup",
  "校验后替换当前数据": "Validate and replace current data",
  "数据与隐私": "Data and privacy",
  "数据仅保存在当前设备，不上传服务器。卸载应用或清理浏览器数据可能丢失记录，请定期备份。可在健康数据页导入系统记录；智能秤直连尚未接入。":
      "Data stays on this device and is not uploaded. Uninstalling the app or clearing browser data may erase your records. Back up regularly. Import system records under Health data; direct smart-scale connections are not available yet.",
  "体脂率需来自测量或手动填写；BMI 和趋势用于个人记录，不作诊断依据。":
      "Body fat must be measured or entered manually. BMI and trends are for personal tracking, not diagnosis.",
  "载入演示数据（非真实测量）": "Load demo data (not real measurements)",
  "清空所有记录？": "Clear all entries?",
  "此操作无法撤销，建议先导出备份。身高和目标设置会保留，系统健康原始记录不会删除。":
      "This cannot be undone. Export a backup first. Height and goal settings will remain. Original system health records will not be deleted.",
  "清空所有记录": "Clear all entries",
  "系统记录请在来源 App 中修改，再到健康数据页重新同步。":
      "Edit system entries in their source app, then sync again under Health data.",
  "记录身体变化": "Add measurement",
  "查看表格全部数据": "All imported fields",
  "以下为文件原始值，修改体重不会改写原始字段":
      "Original file values. Editing weight does not change these fields.",
  "体重 ({0})": "Weight ({0})",
  "请输入 {0}": "Enter {0}",
  "20–1000 斤": "20–1000 jin",
  "体脂率 %（选填）": "Body fat % (optional)",
  "请输入大于 0、小于 100 的体脂率": "Enter body fat greater than 0 and less than 100",
  "测量时间不能晚于当前时间": "Measurement time cannot be in the future",
  "测量时间不能晚于现在，请调整日期或时间":
      "Measurement time cannot be in the future. Adjust the date or time.",
  "备注（选填）": "Note (optional)",
  "删除这条记录？": "Delete this entry?",
  "删除后无法撤销。": "This cannot be undone.",
  "身高与目标": "Height and goal",
  "身高 cm": "Height (cm)",
  "请输入 80–250 cm": "Enter 80–250 cm",
  "目标体重 {0}": "Goal weight ({0})",
  "请输入有效目标体重": "Enter a valid goal weight",
  "导出备份": "Export backup",
  "已复制备份，请粘贴到安全位置保存": "Backup copied. Paste it somewhere safe.",
  "复制失败，请直接选择文本复制": "Could not copy. Select and copy the text instead.",
  "复制 JSON": "Copy JSON",
  "导入备份": "Import backup",
  "粘贴轻衡 JSON 备份": "Paste a Poise / 轻衡 JSON backup",
  "备份格式或数值不合法，请检查完整 JSON":
      "Invalid backup format or values. Check the complete JSON.",
  "校验备份": "Validate backup",
  "替换当前数据？": "Replace current data?",
  "导入 {0} 条手动记录和 {1} 条健康数据，替换当前全部记录和设置。请先备份现有数据。":
      "Import {0} local entries and {1} health samples, replacing all current records and profile settings. Back up your data first.",
  "备份已导入": "Backup imported",
  "载入演示数据？": "Load demo data?",
  "将生成近 45 天的虚构记录，仅用于体验界面，不代表你的身体数据。":
      "Creates 45 days of fictional entries for previewing the app. These are not your measurements.",
  "演示数据 · 非真实测量": "Demo data · Not real measurements",
  "Fitdays 文件导入": "Imported from Fitdays",
  "脂肪量": "Fat mass",
  "肌肉率": "Muscle %",
  "肌肉量": "Muscle mass",
  "骨骼肌率": "Skeletal muscle %",
  "骨量": "Bone mass",
  "蛋白质": "Protein %",
  "蛋白量": "Protein mass",
  "体水分": "Body water %",
  "含水量": "Water mass",
  "皮下脂肪": "Subcutaneous fat",
  "内脏脂肪": "Visceral fat",
  "身体年龄": "Body age",
  "腰臀比": "Waist–hip ratio",
  "基础代谢率": "Basal metabolic rate",
  "去脂体重": "Fat-free mass",
  "标准体重": "Standard weight",
  "时间": "Time",
  "体型": "Body type",
  "肥胖等级": "Obesity category",
  "仅在你点击按钮后读取，不会修改系统健康记录。":
      "Reads only when you tap the button. System health records are never modified.",
  "无法检查系统健康服务，请确认系统和服务版本后重试。":
      "Could not check health services. Check your system and service versions, then retry.",
  "正在请求授权并读取数据…": "Requesting permission and reading data…",
  "没有读到可导入的数据。请检查授权，以及体脂秤 App 是否已向系统健康服务写入数据。":
      "No data to import. Check permissions and whether your scale app has written data to the system health service.",
  "导入读取结果": "Import results",
  "{0}：{1} 条": "{0}: {1} samples",
  "当前身高将更新为 {0} cm，历史 BMI 会随之重新计算。":
      "Height will update to {0} cm. Historical BMI will be recalculated.",
  "已有来源和 ID 相同的记录会更新，不会重复新增。":
      "Entries with the same source and ID will be updated, not duplicated.",
  "已取消导入，本地数据未改变。": "Import cancelled. Local data is unchanged.",
  "已导入或更新 {0} 条健康数据。": "Imported or updated {0} health samples.",
  "保存失败，原有本地数据未改变。": "Could not save. Existing local data is unchanged.",
  "读取失败，本地数据未改变。请检查系统健康服务和读取权限后重试。":
      "Could not read. Local data is unchanged. Check health services and read permissions, then retry.",
  "移除健康数据副本？": "Remove local health copies?",
  "移除全部已导入的本地健康数据，手动记录和系统原始数据会保留。需要时可重新授权导入。":
      "Removes all imported health samples from this app. Manual entries and original system data remain. You can import again later.",
  "已移除本地健康数据副本。": "Local health copies removed.",
  "连接健康数据": "Connect health data",
  "让你的记录，在这里汇合。": "Bring your measurements together.",
  "从 {0} 读取体重和体脂率；身高可选。需要其他健康 App 已向系统写入相应数据。":
      "Read weight and body fat from {0}, with optional height. Another health app must have written these measurements to the system.",
  "系统健康数据接入仅支持 Android / iOS 原生 App，网页预览不支持。":
      "System health integration is available in the Android / iOS app, not the web preview.",
  "读取范围": "Date range",
  "此版本不申请额外历史权限，Android 读取范围最多选择近 30 天。":
      "This version does not request extended history access. Android supports up to the last 30 days.",
  "同时读取并使用最新身高": "Read and use the latest height",
  "选中后会额外请求身高读取权限": "Also requests permission to read height",
  "正在处理…": "Processing…",
  "授权并读取": "Authorize and read",
  "无法打开安装页面，请在应用商店或系统设置中安装、更新 Health Connect。":
      "Could not open the install page. Install or update Health Connect in the app store or system settings.",
  "安装或更新 Health Connect": "Install or update Health Connect",
  "重新检查服务": "Check service again",
  "已保存 {0} 条系统健康数据": "{0} health samples saved",
  "移除导入的本地副本": "Remove imported local copies",
  "数据使用说明": "How your data is used",
  "• 数据只保存在本机，不上传服务器、不用于广告。":
      "• Data stays on this device. It is not uploaded or used for ads.",
  "• 只申请读取权限，不写入或删除系统记录。":
      "• Read access only. System records are never written or deleted.",
  "• 体脂可独立显示趋势；同一来源、相差不超过 5 分钟的体脂才会关联到体重卡片。":
      "• Body fat has its own trend. It is linked to a weight entry only when the source matches and the readings are within 5 minutes.",
  "• 重复同步按来源和原始 ID 更新。系统删除记录不会自动删除已导入副本，可使用上方按钮移除后重新导入。":
      "• Sync updates by source and original ID. Deleting system records does not remove imported copies. Remove the copies above and import again if needed.",
  "• 可在 Health Connect 或苹果健康的 App 权限设置中撤回授权。撤权不等于删除本地副本。":
      "• Revoke access in Health Connect or Apple Health app permissions. Revoking access does not delete local copies.",
  "• iOS 出于隐私不披露读取权限状态，空结果可能是无数据或未授权。":
      "• iOS does not disclose read permission status. Empty results may mean no data or no permission.",
  "• 导出备份会将健康数据写入剪贴板，请妥善保管。":
      "• Exporting a backup copies health data to the clipboard. Keep it secure.",
  "Apple 不披露读取权限状态；空结果可能表示无数据或未授权。":
      "Apple does not disclose read permission status. Empty results may mean no data or no permission.",
  "{0}未获读取授权": "Read permission not granted: {0}",
  "跳过超出支持范围的{0}": "Skipped out-of-range {0}",
  "文件不能超过 10 MB": "File must be 10 MB or smaller",
  "无法读取文件，请将文件下载到手机后重新选择":
      "Could not read the file. Download it to your phone and select it again.",
  "请选择 .xlsx 文件": "Choose an .xlsx file",
  "无法解析文件，请确认它是未加密的 Fitdays .xlsx 导出表格。":
      "Could not parse the file. Choose an unencrypted Fitdays .xlsx export.",
  "导入完成：新增 {0} 条，更新 {1} 条，重复 {2} 条。":
      "Import complete: {0} added, {1} updated, {2} duplicates.",
  "保存失败，原有数据未改变，请重试。":
      "Could not save. Existing data is unchanged. Please retry.",
  "导入历史记录": "Import history",
  "从 Fitdays 接回完整的身体数据。": "Bring your full body history from Fitdays.",
  "支持 Fitdays 导出的 .xlsx 文件（最大 10 MB）。自动识别时间、体重和体脂率，保留表内其他字段。斤自动换算为 kg，不修改身高设置。":
      "Supports Fitdays .xlsx exports up to 10 MB. Detects date, weight and body fat, preserving all other fields. Jin is converted to kg. Your height setting is unchanged.",
  "请确认文件属于当前使用者，本版本不区分多个人的档案。":
      "Make sure the file belongs to you. This version does not support separate profiles.",
  "选择 .xlsx 文件": "Choose .xlsx file",
  "{0} 至 {1}": "{0} to {1}",
  "识别 {0} 条有效记录 · 跳过 {1} 条无效行": "{0} valid entries · {1} invalid rows skipped",
  "新增 {0} 条 · 更新 {1} 条 · 重复 {2} 条": "{0} added · {1} updated · {2} duplicates",
  "预览（最近 5 条，体重以 kg 显示）": "Preview (latest 5, weight in kg)",
  "{0} kg · 体脂 {1}% · {2} 个原始字段": "{0} kg · Fat {1}% · {2} original fields",
  "查看跳过原因": "Why rows were skipped",
  "确认导入": "Confirm import",
  "导入规则": "Import rules",
  "• 追加到现有数据，不清空健康数据或手动记录。":
      "• Adds to existing data. Health samples and manual entries are kept.",
  "• 相同时间、体重、体脂的记录可更新其他字段；不同测量会保留，同一文件重复导入会跳过。":
      "• Entries matching time, weight and body fat can update other fields. Distinct readings are kept; repeat imports are skipped.",
  "• 日历仍只显示体重；点开记录查看原始全部字段，在趋势页选择其他数值指标。":
      "• The calendar shows weight only. Open an entry for all original fields, or choose other numeric metrics in Trends.",
  "• 文字类字段只在详情显示。BMI 主图使用当前身高计算，也可选择“BMI（文件原值）”。":
      "• Text fields appear in entry details only. The main BMI chart uses your current height; “BMI (imported)” shows the file value.",
  "• 文件在本机解析，不上传服务器；关闭预览不会导入数据。":
      "• Files are parsed on this device and never uploaded. Closing the preview does not import data.",
  "{0} 第 {1} 行：日期、体重或体脂格式无效，已跳过":
      "{0}, row {1}: invalid date, weight or body fat; skipped",
  "未找到“时间”和“体重”列，请选择 Fitdays 导出的 .xlsx 文件":
      "Date and weight columns not found. Choose a Fitdays .xlsx export.",
  "没有可导入的有效记录，请检查日期和体重列":
      "No valid entries to import. Check the date and weight columns.",
  "单个工作表最多支持 20000 行": "Each worksheet supports up to 20,000 rows",
  "备份超过 10 MB": "Backup exceeds 10 MB",
};
