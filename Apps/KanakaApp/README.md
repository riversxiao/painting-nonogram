# KanakaApp Apple 集成边界

此目录同时包含：

- `Package.swift`：iOS/iPadOS 17 与 macOS 14 composition 的 SwiftPM executable，以及 Linux fallback sentinel；
- `KanakaApp.xcodeproj`：原生 iOS/iPadOS Application Host，提供可共享的 `KanakaApp` scheme。

两条构建路径共享 `Sources/KanakaApp`，不会复制 UI 或创建第二个 `@main`。Xcode Host 直接引用 `KanakaCore`、`KanakaContentKit`、`KanakaProgress`、`KanakaStory` 与 `KanakaProductDomain` 五个本地 package product。

## 已实现的 Apple 代码路径

- Bundle-backed validated two-Fragment development catalog；
- `playable-experience-v1` sidecar 驱动的中英文本地化标题、介绍与完成反馈；
- 首次世界观介绍、独立且可跳过的 `5×5` 教学，以及修复室/拼豆工坊初始入口；
- Museum → Gallery → Artwork → Repair Fragment 导航；
- 可操作 `5×5 + 1×1` 两阶段彩色 Nonogram flow：单 Canvas 绘制 clues、格状态、稳定符号、锁定与 stroke preview；平台无关 `BoardGeometry` / `BoardInputSession` 提供一次拖画一个 batch、阈值轴锁、补格、取消、缩放/平移 clamp，继续支持 Undo/Redo、autosave 与中间/最终完成反馈；
- 分别使用命名 `KanakaProgress` / `KanakaStory` 配置的 `SwiftDataProgressStore` 与原子 `SwiftDataStoryStateStore`，避免默认持久化文件碰撞；
- scene phase 与离开棋盘时对所有 active controller 执行 `flush()`；
- 外部 `entitlements.json` 商品→Museum 映射、StoreKit 2 verified current entitlements、购买监听、购买与恢复；
- 只接受 `AuthorizedBlueprint` 的 Core Graphics/ImageIO PNG renderer（20 MP ceiling、逐格稳定符号）、材料清单、临时 workspace 与系统分享；
- 档案 milestone、错误状态、Dynamic Type 基础，以及不依赖每格 SwiftUI View 的逻辑光标 accessibility actions。

Bundle 中内容是 synthetic two-Fragment development fixture，不是 Museum 1 正式发布资产。教学直接使用独立 `GameSession`，完成或跳过都不会写入 Fragment Progress、恢复 Artwork 或提交 Story evidence；首次启动状态单独保存于版本化 UserDefaults 记录。商品配置默认为空；SKU、价格、免费组合继续由外部配置决定。Story completion mapping 对 development fixture 保持为空，不冒充 Museum 1 Canon。

## Xcode Host

在 macOS/Xcode 16 或更新版本执行无需签名的 Simulator 编译 gate：

```bash
make build-app-host
# 构建后同时验证 executable、Info.plist 与 Bundle 资源布局
make validate-app-host
```

`.github/workflows/apple-host.yml` 会在相关 Pull Request 上使用 GitHub-hosted `macos-15` runner 自动执行 `make validate-app-host`，因此开发者不需要本地 Mac 即可获得 Apple SDK compile/link 与 Bundle contract gate。gate 会将磁盘 Swift 源码与 Xcode 实际编译的 file list 对比，断言 Bundle ID、可执行文件、iOS 17 和 iPhone/iPad metadata，并对构建产物中的 Content 与 entitlement 配置执行语义校验。workflow 只授予 `contents: read` 权限、禁用 checkout credential 持久化，并且不配置签名、证书或 secrets。

workflow 之外，也可以打开 `Apps/KanakaApp/KanakaApp.xcodeproj`，选择共享 `KanakaApp` scheme 后运行。设备构建需在本地为 target 设置 Development Team；不要把个人 Team ID 写入共享工程。

资源必须保持现有布局：`Resources/Content` 作为完整目录复制到 App Bundle，`Resources/entitlements.json` 位于 Bundle 根目录。composition 在 SwiftPM 下使用 `Bundle.module`，在原生 Host 下使用 `Bundle.main`。新增、删除或移动 App Swift 文件时，必须同时更新 `Package.swift` 资源/target 约定和 Xcode target membership。

当前 Host 最低目标为 iOS 17，并支持 iPhone 与 iPad。Bundle ID 暂为 `com.riversxiao.kanaka`；正式签名、App ID、图标和发布 metadata 应在进入分发前冻结。

## 仍需 Apple/Xcode 验证

Linux 的 `make validate-app` 只校验 Bundle catalog，并编译/运行 fallback sentinel。以下代码在 Linux 被条件编译排除，尚不能声称通过：

- SwiftUI iPhone/iPad/macOS 编译、导航、布局和手势；
- SwiftData reopen、save rollback、并发 transaction visibility 与 migration；
- StoreKit Configuration 购买、pending、revocation、expiration、upgrade 和离线恢复；
- PNG golden pixels、坐标/legend 排版、内存上限和实物打印；
- UIKit Share Sheet iPad presentation 与 macOS ShareLink 生命周期；
- scene suspension/background time、VoiceOver/Voice Control/Switch Control；
- 25×25 production board 的 Canvas/虚拟化性能与真机 60 fps；
- OSLog、MetricKit、PrivacyInfo、正式 App Icon、签名设备构建与归档。

原生 Host、共享 scheme、源码 membership、本地 package links 与 Bundle resource layout 已建立。当前 Linux 环境没有 `xcodebuild`，因此仍需在 macOS/Xcode 16+ 中运行 `make build-app-host`，随后完成模拟器和真机 gate。
