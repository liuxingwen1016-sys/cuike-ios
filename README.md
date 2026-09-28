# 萃刻 · iOS 原生应用

一款离线手冲咖啡伴侣，也是 iOS → HarmonyOS 迁移演示的源端工程。

**2026-09-28 交付状态：业务核心测试通过，已在 GitHub Actions / Xcode 27 完成首轮真机编译并生成 IPA；尚未完成本地 iPhone 签名安装与真机验收。** 当前开发机是 Windows，已通过 USB 检测到 iPhone；型号与 iOS 27.0 由用户提供。最新构建和模拟器测试记录见 [云端验证说明](Verification/GitHubActions验证说明.md)。

## Windows → GitHub Actions → iPhone

将本目录作为 GitHub 仓库根目录，在 Actions 中手动运行 **Build iPhone IPA**。使用 `xcode-27` 云端 Mac，运行核心测试并构建 arm64 真机包，下载 `Cuike-iPhone-unsigned` 后解压得到 `Cuike-unsigned.ipa`。Windows 上通过 Sideloadly 使用自己的 Apple 账户签名并安装。无需在 GitHub 配置 Apple 密码或证书。

完整步骤见 [GitHub Actions 编译及 iPhone 安装](Docs/GitHubActions到iPhone.md)。另一条 **iOS simulator tests** 工作流用于模拟器与 UI 测试，不生成手机安装包。两条工作流均为手动触发，产物保存7天。

## 直接打开

在 Mac 上用 Xcode 打开根目录的 **`Cuike.xcodeproj`**，选择 **Cuike** scheme，再选一台 iOS 17 或更新版本的 iPhone 模拟器，点击 Run。当前云端构建使用 Xcode 27.0 / iOS 27.0 SDK；最低部署版本仍为 iOS 17。

工程已生成并随包交付，不需要先安装 XcodeGen、CocoaPods、第三方库，也不需要后端服务或 API Key。`Package.swift` 仅供独立运行业务核心测试，主应用请打开 `.xcodeproj`。

第一次启动会创建3袋示例豆、3份配方、3条示例风味记录。测试运行可传入 `--uitesting`，使用独立的内存数据库，不修改日常数据。

## 这版已写入的功能

| 范围 | 实现 |
|---|---|
| 冲煮台 | 最近配方、未完成会话入口、真实记录数和均分、最近一杯 |
| 豆档案 | 搜索、处理法筛选、新建、编辑、归档/恢复、删除无引用的自建豆 |
| 配方 | 粉量、粉水比、水温调节，水量联动，保存参数，历史参数复用 |
| 冲煮 | 180秒三阶段、单会话、提前结束、后台/重启时间戳恢复、时钟异常确认 |
| 风味手记 | 五星、酸甜醇厚、标签和笔记，编辑、删除、最近7杯图表、系统分享 |
| 原生识别 | Vision 图片 OCR、PhotosPicker 选图、VisionKit 实时扫描、人工确认、手填兜底 |
| 系统延伸 | ActivityKit 锁屏/灵动岛倒计时、WidgetKit 最近配方、App Shortcut 打开上次配方、授权后的本地完成通知 |
| 适配 | 深浅色、跟随系统大字、减少动态效果、读屏标签、可关闭触感 |

相机、图片识别、触感、实时活动、小组件和快捷指令已接真实系统 API，但都还需要 Mac/iPhone 实测。这不是 WebView 套壳；之前的 HTML 原型保留在上级 `design/cuike`，不参与应用构建。

## 没有 Mac 时怎样接着验证

1. 借用团队 Mac，或使用允许远程桌面与 Xcode 模拟器的云 Mac。从 Windows 连接后打开本工程。
2. 先跑模拟器主链路：调整配方 → 开始 → 提前结束 → 评分保存 → 回历史复用。
3. 再用真实180秒测试切后台、冷启动恢复。不要用网页快进代替原生计时测试。
4. 最后用临时借用的 iPhone 核验相机、触感与系统表面。云真机可以补充交互检查，不能代替亲自体验震动。

现已创建 [萃刻私有仓库](https://github.com/liuxingwen1016-sys/cuike-ios)，使用 GitHub 托管 Mac 构建；未租用独立云 Mac。Actions 的额度和费用以 GitHub 账户账单为准。

## 签名与系统能力

模拟器构建一般不需要开发团队。真机与 App Group 功能需要使用你自己的开发团队和可用能力配置。

1. 复制 `Config/Local.xcconfig.example` 到工程根目录，命名为 `Local.xcconfig`。
2. 填写 `DEVELOPMENT_TEAM`、唯一的 `BUNDLE_PREFIX` 和 `CUIKE_APP_GROUP`。
3. 主应用和 `CuikeWidgets` 扩展均使用相同 App Group；在 Xcode 的 Signing & Capabilities 中确认该组已注册并包含在两个目标的配置中。
4. 如系统签名环境不支持 App Groups，先验证应用主流程。不要将空白小组件归为已验收。

固定 Bundle ID 默认 `com.cuike.brew`；这是可修改的工程默认值，不代表已在 Apple 注册。

## 测试与证据

| 检查层 | 本次状态 |
|---|---|
| Swift 6.0.3 语法解析 | 通过，不等于 Apple SDK 类型检查 |
| Xcode 工程引用、资源、plist、scheme | 通过，详见 `Verification/project-checks.json` |
| 纯 Swift 业务核心 XCTest | 12项通过，在本机 WSL / Swift 6.0.3 执行 |
| SwiftData 持久化与业务集成测试 | 已编写4项，已提交云端模拟器任务，结果待确认 |
| iOS UI 自动化 | 已编写2项，已提交云端模拟器任务，结果待确认 |
| iOS 主应用及扩展真机编译 | GitHub Actions / Xcode 27 首轮通过，IPA 已生成 |
| 模拟器启动、真机安装与系统功能 | 以云端验证说明和后续真机验收记录为准 |

在正常安装 Swift 的环境运行核心测试：

```sh
swift test
```

在 Mac 一次完成核心测试、模拟器构建与 iOS 测试：

```sh
bash Scripts/verify-mac.sh
```

脚本会选一台已安装的 iPhone 模拟器，并输出日志与 `.xcresult` 到 `build/`。也可用 `CUIKE_SIMULATOR_ID` 指定设备。共享 scheme 包括单元测试和 UI 测试；可在 Xcode 中直接按 Command-U。详细人工验收见 `Docs/验收清单.md`。

`.github/workflows/build-iphone.yml` 负责真机 IPA；`.github/workflows/ios.yml` 负责模拟器测试。远端仓库直接使用本 `ios` 目录作为根目录；若保留外层目录结构，需相应调整工作流位置和工作目录。

## 结构

```text
App/                  SwiftUI 页面、SwiftData 模型、应用状态和平台服务
Core/                 不依赖 Apple UI 的配方、计时、识别文本解析与路由规则
Shared/               主应用与扩展共享的实时活动属性、组件快照
Widgets/              桌面组件和锁屏/灵动岛布局
Resources/            明暗色、图标、原创 OCR 示例、隐私清单
Tests/                核心、SwiftData 集成和 UI 测试
Config/               标识、签名与部署配置
Scripts/              工程生成、静态检查、Mac 验证
Verification/         本次已执行检查结果与阶段说明
```

工程随带 `Scripts/generate_project.py`，新增源文件后可以重新生成 `.xcodeproj`；它会重写 Info.plist、entitlements 和共享 scheme，修改这些生成项时请同步改脚本。运行现有工程不需要 Python。重新生成图片才需要 Pillow；图片已打包。

## 已知边界

- iOS 17 为功能基线；未实现专门的 iOS 26 Liquid Glass 分支与 iPad 双栏，属于 PRD 的 P2。
- 拍摄/选图只在建档确认中预览，未长期保存豆袋原图，豆卡使用原创矢量插画；不收集或上传照片。
- OCR 是真实识别，但结构化解析采取保守规则：只提取有名称/产地/处理法/烘焙度明确标签的字段。任意包装文字仍需人工填写；不伪造置信度或识别结果。
- Live Activity 使用系统日期计时。后台不保证三阶段逐段更新或触感；到期后最终清理由下次回前台执行。系统可自行限制或移除活动。
- Widget 读 App Group JSON 快照并请求系统刷新，不能承诺立即更新，不承担逐秒计时。
- 进程存活时用单调时钟检测时间调整；冷启动后能识别明显向后跳时，但没有可信外部时钟时无法区分向前改时与真实经过时间。
- 无账户、云同步或数据导入；支持单杯文字分享。此版尚未上架，未生成可安装 `.ipa`，也未开始鸿蒙迁移。

## 官方接口依据

- [模拟器与真机运行](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- [SwiftData ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [VisionKit 相机扫描](https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera)
- [ActivityKit 请求实时活动](https://developer.apple.com/documentation/activitykit/activity/request(attributes:content:pushtype:))
- [App Intents](https://developer.apple.com/documentation/appintents)
- [隐私清单中的 API 使用原因](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
