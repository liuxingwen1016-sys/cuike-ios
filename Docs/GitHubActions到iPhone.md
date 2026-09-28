# 萃刻：Windows 编译及 iPhone 安装教程

更新：2026-09-28。当前路线：Windows 修改代码 → GitHub Actions 的 Mac/Xcode 编译 → 下载真机 IPA → Windows 使用 Sideloadly 签名 → 本地 iPhone 安装。

这条路线不要求自己拥有 Mac，也不要求 Windows 安装 Xcode。先用普通 Apple 账户完成个人设备安装；不需要先购买付费开发者会员。GitHub 负责编译，手机安装还需要 Apple 签名，二者是不同步骤。它适合改代码、重新打包、真机体验；不能让 Windows 获得 Xcode 的实时断点调试界面。

## 1. 仓库和本地目录

工程根目录是 `D:\Ios2Harmony\ios`，应直接包含 `Cuike.xcodeproj`、`App`、`Scripts` 和 `.github`。

本项目已创建私有仓库 [liuxingwen1016-sys/cuike-ios](https://github.com/liuxingwen1016-sys/cuike-ios)，并完成首轮原生编译。最新执行结果见 `Verification/GitHubActions验证说明.md`。

只上传此 iOS 工程，不需要上传上级的研究仓库、网页设计包或整个 D 盘。不要仅把源码 ZIP 上传到 GitHub；Actions 需要看到真实的 `.github/workflows/build-iphone.yml` 文件。

如以后在另一台 Windows 从零设置，先安装 [Git](https://git-scm.com/downloads/win) 和 [GitHub CLI](https://cli.github.com/)，在 PowerShell 执行：

```powershell
gh auth login --hostname github.com --git-protocol https --web
gh repo clone liuxingwen1016-sys/cuike-ios
Set-Location cuike-ios
```

本机已经安装 Git、GitHub CLI，并已登录 GitHub，不需要重复创建仓库。Apple 密码、验证码、证书不放进源码或 GitHub Secrets。

## 2. 点击编译

1. 登录 GitHub，打开 [萃刻私有仓库](https://github.com/liuxingwen1016-sys/cuike-ios)。需要使用有仓库权限的账号。
2. 点击顶部 **Actions**。
3. 左侧选择 **Build iPhone IPA**。
4. 点击 **Run workflow**，分支选择 **main**，再点击绿色 **Run workflow**。
5. 打开新出现的运行记录。黄色表示运行中，绿色表示这次测试和打包成功，红色表示失败。

若没有按钮，检查工作流是否在默认分支、自己是否有写权限，以及仓库是否启用了 Actions。GitHub 的手动入口要求工作流包含 `workflow_dispatch` 并存在于默认分支。[官方手动运行说明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)

本工程使用 `xcode-27` runner，明确选择 Xcode 27.0，用于当前 iOS 27.0 设备路线。该 runner 目前是 Public preview；以后标签或镜像发生变化时，应先核查官方清单，再修改工作流。`macos-latest` 不保证始终包含所需的 Xcode。私有仓库使用账户 Actions 额度，超出额度按账户计费设置处理；可在 GitHub 的 Billing 页面查看。工作流仅手动触发，不会每次改文档都消耗构建资源。[GitHub runner 说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

## 3. 下载 IPA

1. 进入刚才成功的运行记录，滚动到 **Artifacts**。
2. 下载 **Cuike-iPhone-unsigned**。浏览器会下载一个 ZIP。
3. 在 Windows 解压，找到 **Cuike-unsigned.ipa** 和 `build-info.txt`。
4. 后面拖入安装工具的是 `.ipa` 文件，不是外层 ZIP。

`Cuike-build-logs` 是排查编译问题的日志，不是安装包。产物保留7天，过期后可重新运行工作流。下载产物需要登录有读取权限的 GitHub 账号。[官方下载说明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)

这个 IPA 含 arm64 主应用，以及小组件/实时活动扩展。文件名中的 `unsigned` 表示它没有可供 iPhone 安装的 Apple 开发证书签名；打包脚本只使用本地临时签名保留能力信息。它必须经过下一步重新签名。手机浏览器下载 IPA、直接点文件、或把模拟器 `.app` 改名为 `.ipa` 都不能替代签名安装。

## 4. Windows 准备安装工具

打开 [Sideloadly 官方网站](https://sideloadly.io/)，选择 **Windows 64-bit**。按官网 Windows 前置条件，从该页提供的 Apple 链接安装 **网页版 iTunes 和 iCloud**；官网要求使用网页版而非 Microsoft Store 版。遇到版本冲突时按官网说明处理，不混装多套驱动。

用数据线连接 iPhone，解锁屏幕，在手机弹窗点击“信任这台电脑”，输入手机密码。先确认 iTunes 能识别设备，再打开 Sideloadly。

本机此前仅确认 Windows USB 设备列表出现 Apple iPhone，这还不等于 Sideloadly 的驱动、配对和签名步骤已经成功。iOS 27.0 上的实际安装仍需本机验证；Sideloadly 官网目前写的是 iOS 26+ 及未来版本支持，不能把这个表述当作本手机已经测通的证据。[Sideloadly 兼容性与故障说明](https://sideloadly.io/faq)

## 5. 签名并安装萃刻

1. 在 Sideloadly 的设备列表选中这台 iPhone。
2. 将 **Cuike-unsigned.ipa** 拖入窗口。
3. 填写你自己的 Apple 账户。使用 **Apple ID sideload** 签名模式，保持默认设置开始；不要选择要求已有有效签名的 Normal Install。
4. 点击 **Start**。按工具提示，在自己电脑上输入密码、完成 Apple 验证。无需把这些信息发到聊天或 GitHub。
5. 等待工具报告完成，再在 iPhone 上寻找“萃刻”图标。

首轮保留扩展，不主动勾选移除 PlugIns。若安装失败，保留报错文字并查看下面的故障表，不要反复更换 Bundle ID。

## 6. iPhone 开启开发者模式及信任

如果提示“需要开发者模式”，进入 **设置 → 隐私与安全性 → 开发者模式**，打开开关，按提示重启，重启后再次确认开启。

首次找不到这个入口时，先完成或尝试安装开发签名应用，再回到设置查看。Apple 说明：在不使用 Xcode 的情况下安装开发签名应用，也能让该菜单出现。因此这条路线不必先借 Mac 只为显示开关。[Apple 开发者模式说明](https://developer.apple.com/videos/play/wwdc2022/110344/)

如果提示“未受信任的开发者”，进入 **设置 → 通用 → VPN 与设备管理**，找到用于签名的 Apple 账户并信任，按屏幕上的验证提示操作。然后再打开萃刻。开发者模式和信任开发者是两个独立步骤。[Sideloadly 信任操作说明](https://sideloadly.io/faq)

## 7. 第一轮真机验收

先验证一条完整业务链：打开最近配方 → 将粉量调到18g、粉水比保持1:16，确认总水量288g → 开始冲煮 → 提前结束 → 评分保存 → 在风味手记看到记录。

接着测试拍照/选图 OCR、深浅色、关闭应用后记录仍在。最后按 `Docs/验收清单.md` 分别验收真实180秒计时、锁屏实时活动、灵动岛、桌面小组件和快捷指令。允许通知后，才能验收后台完成提醒。

小组件使用 App Group 共享数据，重新签名后需要有效的组权限、主应用与扩展的组标识一致，并与两者 `Info.plist` 中的 `CuikeAppGroup` 一致。仅保留扩展文件不能证明这些条件成立。空白小组件不算通过验收。

如 Sideloadly 报错明确指向扩展或 App Group，可先记录错误，再尝试其 **Remove app extensions / PlugIns** 选项安装主应用，验证配方、冲煮、手记和 OCR。这属于功能降级：桌面小组件和锁屏/灵动岛实时活动界面将不可用。不要把降级安装当作完整系统能力演示通过。后续完整验收需修正主应用/扩展/App Group 的签名与配置，必要时转用具备正确证书及 provisioning profile 的云端签名流程。

## 8. 更新代码和续签

本机代码有更新后，在 PowerShell 逐条执行；出现红色错误时先停止处理错误：

```powershell
Set-Location D:\Ios2Harmony\ios
git status
git add .
git commit -m "Update Cuike"
git push
```

然后重复 **Actions → Build iPhone IPA → Run workflow → 下载 IPA → Sideloadly**。这是重新编译；手机不需要每次重新开启开发者模式。

普通免费 Apple 账户的侧载签名通常有效7天；到期需续签。代码没变化时通常可再次使用原 IPA。保持同一 Apple 账户和同一应用 Bundle ID，覆盖安装，尽量避免删除应用导致本地记录丢失。Sideloadly 的自动刷新需要电脑运行配套后台程序，并能通过 USB 或配置好的 Wi-Fi 发现设备；不是手机离开电脑后永久自动续签。[有效期、覆盖安装及自动刷新说明](https://sideloadly.io/faq)

## 常见问题

| 现象 | 先检查什么 |
|---|---|
| Actions 一直等待 runner | 查看 `xcode-27` 可用性、账户额度及仓库 Actions 限制。预览镜像可能排队；不要连续重复创建运行。 |
| `Run core tests` 或构建步骤红色 | 打开失败步骤的第一条 `error:`；下载 `Cuike-build-logs`。这是代码/编译问题，与手机信任设置无关。 |
| 只有日志，没有 IPA | 本次打包未成功。应先修复红色步骤，不能从日志 ZIP 安装。 |
| `No devices detected` | 手机解锁并信任电脑；检查官网要求的 iTunes/iCloud 及 USB 数据线。 |
| `Developer Mode Required` | 按第6节开开发者模式、重启并二次确认。 |
| `Untrusted Developer` | 按第6节在 VPN 与设备管理中信任签名账户。 |
| entitlement / App Group / PlugIns 报错 | 保留完整错误，检查主应用和扩展签名。降级移除扩展会失去系统界面能力。 |
| 约一周后打不开 | 先按第8节续签，再看是否有其他错误。 |
| App ID 或侧载应用数达到免费账户限制 | 查看 Sideloadly 的具体错误，避免连续更换标识创建更多 App ID。 |

后续排查时提供：失败步骤名称、错误文字、Actions 运行链接，以及手机上实际出现的提示。密码和验证码不需要提供。
