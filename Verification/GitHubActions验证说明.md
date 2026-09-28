# GitHub Actions 原生构建验证

日期：2026-09-28。此记录接续第一阶段 Windows / WSL 验证。

## 已确认

- 私有仓库：[liuxingwen1016-sys/cuike-ios](https://github.com/liuxingwen1016-sys/cuike-ios)。
- 真机编译：[成功运行 36374603242](https://github.com/liuxingwen1016-sys/cuike-ios/actions/runs/36374603242)。
- 验证提交：`a010eb30c4d4bc7cced9b0f0b480aa94467161d9`。之后仅交付文档、归档及源码打包脚本更新不改变此 IPA 中的应用代码。
- 环境：GitHub `xcode-27` runner，Xcode 27.0（27A266a），iOS 27.0 SDK。
- 纯 Swift 业务核心：12项 XCTest，0失败；本次直接执行工程中的 `swift test`。
- 主应用和 WidgetKit / Live Activity 扩展均完成 Release / iphoneos 构建，日志结尾为 `BUILD SUCCEEDED`。
- IPA 已下载到本机 `D:\Ios2Harmony\安装包\Cuike-unsigned.ipa`，大小632,498字节。
- 本地核对 ZIP CRC、主应用与扩展的 `iPhoneOS` 标记、arm64 Mach-O 文件头、最低系统 iOS 17.0，以及下载后 SHA256 与云端一致。
- 主应用 Bundle ID：`com.cuike.brew`；扩展：`com.cuike.brew.CuikeWidgets`。
- SHA256：`75c333373ea1266c9c125f55d80985cdfbe51bc3e1fdda0550956eee271fb383`。
- 构建元数据：[cloud-build.json](cloud-build.json)。原始日志已保留于本机 `build/logs/36374603242`；云端 `Cuike-build-logs` 产物保留7天。

首轮 [36374410776](https://github.com/liuxingwen1016-sys/cuike-ios/actions/runs/36374410776) 也通过。随后明确 SwiftData 数据库保存在主应用私有目录，仅小组件 JSON 快照走 App Group，再完成上面这次构建。当前交付 IPA 对应后一次构建。

## 模拟器测试

[模拟器运行 36374610071](https://github.com/liuxingwen1016-sys/cuike-ios/actions/runs/36374610071) 已触发；本次交付整理时仍在运行，尚未取得测试结果，因此不计为通过。后续状态以运行页面为准。不能用真机编译成功替代启动和交互测试结果。

## 尚需手机验证

此 IPA 没有可安装的 Apple 开发证书签名，仅含保留 entitlement 信息的本地临时签名。需由用户在 Windows 的 Sideloadly 内使用自己的 Apple 账户重新签名，然后安装到 iPhone。尚未声称安装或真机功能验收成功。

OCR 相机、触感、后台通知、实时活动、灵动岛、小组件、快捷指令以及重签后的 App Group 共享，均需按验收清单逐项验证。编译日志中有 App Intents 的 `Could not archive SSU artifacts` 诊断及 iPad 方向提示，未导致构建失败；快捷指令的识别和运行不能据此视为通过。当前重点是 iPhone，iPad 适配尚未完整验收。

## 本机下载排障

GitHub CLI 下载新版产物时遇到 TLS/EOF 中断。核查发现本地系统代理连接不稳定；仅对此次下载使用直连 HTTPS，成功取回产物并核对哈希，没有修改机器的代理设置，也没有改变仓库可见性。

后续操作见 [编译与安装教程](../Docs/GitHubActions到iPhone.md)。
