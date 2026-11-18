# 验证记录

2026-11-17，Flutter 3.29.3 / Dart 3.7.2，Linux。

- 静态检查：`flutter analyze`，无问题。
- 自动化测试：`flutter test --reporter expanded`，9 项通过。
- Web 构建：`flutter build web --release --pwa-strategy=none --no-web-resources-cdn`，通过。
- Chromium 390 × 844、2 倍像素密度，手动检查截图：日历与趋势正常，45 条虚构记录，无浏览器 pageerror。
- 320 与 390 逻辑像素宽度通过 Widget 布局测试。
- 本轮修复：月份标题、趋势统计和日期行在窄屏下的溢出；趋势横轴使用自然日差，避免夏令时偏移。

自动化测试范围：

1. 时段 12:00 / 18:00 边界、当日多次记录取最后一次、缺测日期。
2. kg/斤换算保持内部 kg，BMI 计算。
3. 备份往返，保留时间、备注、可空体脂和设置。
4. 拒绝未知版本、非法范围、重复 ID 的备份。
5. 界面新增、编辑、持久化、单点趋势和单位切换。
6–7. 两种窄屏布局、无体脂区间、切换 BMI 与全年、删除取消和确认。
8. 损坏存储不覆盖原数据，暂停写入。
9. 持久化后重新加载。

限制：未构建或安装 Android APK/iOS IPA；未验证真实设备系统健康数据、蓝牙与系统权限。

`tools/preview.cjs` 是当前环境的可选截图脚本，需要 Node.js、Playwright 和 `/usr/bin/chromium`；运行前先服务 `build/web` 于 4173 端口。脚本使用隔离浏览器，演示数据不会写入用户浏览器。


## 0.2.0 健康数据接入（2026-11-17）

- 静态检查无问题，自动化测试 16 项通过。
- 新增接入测试：Android 部分授权、仅 READ 请求；HealthKit 体脂分数转换、身高转换；查询错误；来源/UUID 更新；独立体脂；version 1 迁移。
- 新增界面测试：取消导入不保存、确认导入、重复导入不重复、移除本地副本保留手动记录。
- `flutter build apk --release` 成功，最后一次构建 65.0 秒。
- 包名 com.qingheng.bodylog，versionName 0.2.0，versionCode 2；minSdk 26，targetSdk 35。
- APK 包含 arm64-v8a / armeabi-v7a / x86_64，为通用测试包，63,630,288 字节。
- apksigner 验签通过（v2），证书 CN=Qingheng Test Build，RSA 2048 测试签名。
- 声明的健康权限仅 READ_WEIGHT / READ_BODY_FAT / READ_HEIGHT；未声明健康写入、后台读取或额外历史权限。
- 已核对 Health Connect 权限用途 Activity 和 rationale intent；APK ZIP 完整性检查通过。
- HealthKit plist 格式检查通过，三个 Runner 配置均指定 entitlement，iOS 最低 14.0；没有在 Linux 构建 IPA。
- 最终 APK SHA-256：`e636f23f5fb233f728e5fa50159c8c8ffff23750cade0b66b05153dfd8237bfd`。
- 未进行 Android/iOS 模拟器、真机安装与系统健康记录读取验证。接口测试使用模拟健康提供者。


## 0.3.0 文件导入与所有字段

- 最终静态检查无问题；23 项测试通过，包括以环境变量在本地读取私有样本，验证 186 条有效记录、22 个字段、重复导入以及同分钟不同测量保留。
- 新增 UI 测试：选择文件后先预览不保存、确认导入、重复预览、原始全部字段、额外数值指标趋势、日历仍为体重。
- Android release APK 构建通过（107.7 秒），版本 0.3.0 / versionCode 3，测试签名证书与 0.2.0 相同，可覆盖更新。
- APK ZIP 完整性检查通过，不含 XLSX 样本。
- APK 大小：65,110,561 字节，SHA-256 `1d5dd1d15536bc45c1d3bacf30ba5b24c735da30de213cef9d9dd6d96e90dc02`。
- 系统文件选择器和覆盖安装仍需真实手机验收；未在模拟器/真机实际选择文件。


## 0.4.0 Apple 风格调整与底部记录固定（2026-11-18）

- 28 项测试通过，包括用户样本、宽屏导航切换、1.3 倍字体、320×640/390×844 和六行月份下当日数值始终位于导航栏上方；多条当日记录独立滚动。
- 静态检查无问题，Web release 和 Android release APK 构建通过（最终 APK 构建 90.2 秒）。
- Chromium 手机/桌面截图使用虚构演示记录，无 pageerror；核对日历固定记录区、趋势、设置和桌面侧栏。
- Android 0.4.0/versionCode 4，签名证书与旧版一致，可覆盖更新；APK ZIP 完整性通过，未包含 XLSX。
- 文件大小 65,014,535 字节，SHA-256 `b50a578a2870c293eced3592ede60c0d5d895a558203f28b04e08bc6ee15fcac`。
- 真机外观、系统文件选择器与 Health Connect 授权尚待真机回归。


## 0.4.1 横向切换与收紧面板

- 全量 29 项测试通过；追加单条卡片底部留白上限检查，多条记录测试改为横向切换与页码断言。
- 最后分离卡片滚动控制器后，日历专项 4 项再验证通过；静态检查无问题。
- Web release 与 Android release 构建通过，APK 0.4.1/versionCode 5，证书与旧版一致。
- Chromium 演示截图包含两条当日记录，显示 1/2 页码；未出现 pageerror，实际检查了卡片到导航之间的小间距。
- APK ZIP 完整性通过，无 XLSX；大小 65,080,147 字节，SHA-256 `99d6cfde1d9b9515095ca0c20b61372c35710fc874540400ed61caacdff4452f`。
- 尚未进行真机回归。

## 0.5.0 外观、图标与时间限制

- 全量 33 项测试通过，包含未来时间拦截、外观切换与持久化、跟随系统及用户样本导入。静态检查无问题。
- 手动新增/编辑校验当前时间，日期选择器截至今天；导入数据保留原始时间。
- Web release、Android release 构建通过；Chromium 浅色/深色手机与桌面截图无页面错误，已检查深色日历、趋势和设置页。截图为虚构数据。
- 新标识由图像生成工具制作，源图保留于 assets/brand/qingheng.png；官方 flutter_launcher_icons 生成各平台图标。
- APK 0.5.0/versionCode 7，签名与旧版相同；ZIP 完整，无 XLSX。大小 67069821 字节，SHA-256 `2873314f858432ca45429c43995e42bdf277a62f6b4a663cd683674f28090910`。
- 未进行真机安装、系统健康权限或系统文件选择器回归；Linux 未构建 IPA。

## 0.5.1 稳定记录区高度

- 静态检查无问题；全量 34 项测试通过，1 项私有样本测试未提供环境变量而跳过。
- 新增 320×640、390×844 回归：有备注/无备注横向切换、有记录/空日期往返，以及首帧与动画结束后，记录区与日历矩形保持相等。
- Android release 构建通过，0.5.1/versionCode 8，签名与旧版一致。APK 完整性通过，无 XLSX；SHA-256 `712ec84efc0f5b78b8ea4646c7aebe0ee6a3964beb2f34587b883213b399041e`。
- 未进行真机回归。

## 0.6.0 Poise 与中英文切换

- 静态检查无问题，全量 41 项测试通过，包括用户私有样本（仅在本机通过环境变量读取）。新增语言切换、重启记忆、跟随系统、数据不改写、320/390 英文日历编辑及趋势/导入/健康页测试。
- Chromium 英文手机及桌面截图使用虚构演示数据，无 pageerror；已检查英文日历与设置页。Web release 构建通过。
- Android/iOS 系统名称与健康数据说明新增英文资源，iOS plist 语法校验通过；Linux 未构建 IPA，未进行真机健康读取回归。
- GitHub 源码交付排除签名密钥、构建缓存、APK 和个人 XLSX。项目保留中文兼容名称及包标识，覆盖安装继续保留数据。
- Android release 0.6.0/versionCode 9 构建通过；旧证书验签通过。APK 完整无 XLSX，67234321 字节，SHA-256 `43bb28d778bd6f2981747d5e854c4418226d52e4d8d7f055c2f4d4b4203ee678`。

## 0.7.0 前台自动同步

- 静态检查无问题，全量 51 项测试通过，包括私有 Fitdays 样本仅在本机读取。
- 验证 Android 自动读取不请求授权、部分授权跳过被拒字段；HealthKit 在读取权限状态未知时仍不申请授权。
- 验证冷启动迁移、重开去重、快速前台切换节流、未连接/关闭/不支持/失败时不改写数据、关闭开关取消在途结果、空结果保留样本、在途查询不覆盖手动保存。手动健康导入后连接设置持久化，移除副本会关闭自动同步。
- 自动同步仅在前台运行，按上次范围读取，Android 最大 30 天，默认不新增身高权限。没有新增后台权限。
- 尚未进行 Android / iPhone 真机健康服务回归；Linux 未构建 IPA。
- Android release 0.7.0/versionCode 10 构建与旧证书验签通过；APK 完整，无 XLSX。大小 67250705 字节，SHA-256 `095873e61cc830972b82820b1b0f8c6b05213183105ae50f5dee7e0951a8bfa4`。

## 0.7.1 个人设置布局

- 静态检查无问题；全量 51 项测试通过，包含窄屏日历固定区、中英文、大字体、导入和健康数据回归。
- 语言/外观设置与存储逻辑保持原样，单位转换规则不变。
- Web 与 Android release 构建通过；中英文、深浅色手机与桌面预览均无 pageerror；检查了趋势、设置、导入和编辑截图。Web 健康页仅验证不支持系统连接时的页面，原生健康服务仍需真机回归。
- APK 0.7.1/versionCode 11，旧证书验签通过；完整无 XLSX。SHA-256 `77549caddc938cd1093d46b19a898357656e96cfb2e5d2238a81a60dacc7aecf`。

## 0.8.0 Keep 日期级接入

- 静态检查无问题，全量 63 项测试通过；新增 12 项 Keep 单元及界面测试，包含 SSE、账号日期更新、日期精度、未识别/冲突数据跳过、安全凭据存储接口、取消授权、导入前不保存、失败保留以及中英文页面。私有 Fitdays 样本仍只在本机读取。
- 活体服务查询确认可以返回规范的日期级体重文本。个人数据与授权凭据未加入源码或发布截图；测试使用虚构 fixture。
- 新备份 schema 3 保留独立 keepSamples，旧版本 1 / 2 可读取；系统健康自动同步不使用 Keep 登录状态。
- 尚未做 Android 真机扫码跳转、安全存储与导入回归；Linux 未构建 IPA。

- Android release 0.8.0/versionCode 12 构建通过，旧证书验签通过；APK ZIP 完整且不含 XLSX。大小 69017252 字节，SHA-256 `e8bf6cff21f18a1b708348a546c25e1fc5b4175e5bc9c8c5c2dba12181dad536`。
- Web release 构建通过；中英文、深浅色截图预览无运行错误。新增 Keep 连接尚未在 Android / iOS 真机验收；iOS 未构建 IPA。

## 0.8.1 Keep 本机授权与官方图标

- Keep 连接先检测本机安装状态，直接打开官方授权 webview，不渲染或请求二维码图片。Android 仅查询并显式指定 Keep 包；iOS 配置 keep 查询 scheme。
- 使用 Keep 官方应用商店图标，来源记录在 assets/integrations/README.md。
- 静态检查无问题；全量 67 项测试通过。新增检测缺失时不创建会话、直接唤起和重新打开、唤起失败不接受登录、授权链接严格校验与通道参数验证。旧版取消授权和数据导入回归继续通过。
- Keep 官方公开授权页面脚本确认采用 keep://webview/ 加编码 URL 的路由。Android / iOS 真机授权跳转仍待验证，iOS 未构建 IPA。

- Android release 0.8.1/versionCode 13 与 Web release 构建通过；APK 沿用旧测试签名，ZIP 完整且无 XLSX。大小 69008393 字节，SHA-256 `9d565ea41b65a934f70bdcb47678093655c736321cefa67fd1b440467d75a6a2`。中英文深浅截图检查无运行错误。
