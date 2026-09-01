# Kanaka 开发与 App Store 发布规划

> 状态：Draft v2
> 目标平台：iOS / iPadOS
> 架构原则：一个 App、两个可切换路径、一个共享内容与权益模型

## 1. 技术决策

| 层 | 选择 |
|---|---|
| 语言 | Swift 6.x |
| UI | SwiftUI |
| 棋盘 | SwiftUI `Canvas` + Core Graphics；复杂手势必要时桥接 UIKit |
| 游戏核心 | 独立 Swift Package：`KanakaCore` |
| 内容协议 | 独立 Swift Package：`KanakaContentKit` |
| 本地存储 | SwiftData；格子状态压缩为 `Data` |
| 权益 | StoreKit 2 + 可测试的 entitlement resolver |
| 音视频 | AVFoundation / AVKit |
| 动画 | SwiftUI / Core Animation；SpriteKit 仅按需 |
| 云同步 | V1.1 可选 CloudKit |
| 日志与性能 | OSLog、MetricKit、Xcode Organizer |
| 测试 | Swift Testing / XCTest / XCUITest |
| CI/CD | Xcode Cloud 或 GitHub Actions + TestFlight |

建议 Deployment Target 为 iOS 17 / iPadOS 17，并在提交时使用 Apple 要求的最新 Xcode 与 SDK。部署目标不因构建 SDK 更新而自动提高。

## 2. 领域层级与工程边界

唯一内容层级：

```text
Museum
└─ Gallery
   └─ Artwork
      └─ 1–4 RepairFragments
         └─ PuzzleDefinition
```

Gallery 是内容实体，Chapter 只是 Gallery 承载的叙事映射；Museum 1 可 1:1。专业蓝图库以 Museum 为内容与权益边界。Museum 2 是新增 Galleries、Artworks、puzzles 与 blueprints 的新范围。

工程不得把 Museum 蓝图库权益解释为进度：权益不会修改 RepairFragment、Artwork、Gallery/Chapter、Museum 或 Story 状态。

## 3. 工程结构

```text
painting-nonogram/
├── Apps/
│   └── KanakaApp/
├── Packages/
│   ├── KanakaCore/
│   ├── KanakaContentKit/
│   └── KanakaDesignSystem/
├── Tools/
│   └── kanaka-content/
├── Content/
│   ├── Sources/
│   │   └── museums/
│   │       └── {museum-id}/
│   │           └── galleries/
│   │               └── {gallery-id}/
│   │                   └── artworks/
│   │                       └── {artwork-id}/
│   │                           └── fragments/
│   ├── Compiled/
│   ├── Localization/
│   └── Rights/
├── Resources/
│   ├── Audio/
│   ├── Video/
│   ├── UI/
│   └── Fonts/
├── StoreKit/
├── Tests/
├── Scripts/
└── docs/
```

素材生成方式不属于 App 架构。游戏只读取经过验收的答案蒙版、作品图、音频、视频和元数据。

## 4. 功能模块

### 4.1 `KanakaCore`

不依赖 SwiftUI、StoreKit 或 SwiftData：

- `PuzzleDefinition`
- `LineClue`
- `CellState`
- clue generator
- 唯一解 solver
- 可解释 hint step
- `GameSession` 状态机
- Undo/Redo transaction
- 完成判断
- bitset 编解码
- 难度评分

内容工具与 App 共用该包，避免编译规则和客户端规则不一致。

### 4.2 `KanakaContentKit`

Codable schema：

- `museum-v1`
- `gallery-v1`
- `artwork-v1`
- `repair-fragment-v1`
- `puzzle-definition-v1`
- `blueprint-v1`

职责：manifest、资源引用、SHA-256 内容哈希、schema migration、权利记录引用与跨实体关系校验。编译产物可以被封装为传输包，但传输包不是产品权益边界。

### 4.3 App Features

- `RestorationFeature`：Museum、Gallery、Artwork、棋盘、完成动画和故事事件。
- `WorkshopFeature`：按 Museum 组织的蓝图库、材料和导出。
- `ArchiveFeature`：收藏展示和档案卡，避免与 Gallery 实体同名。
- `EntitlementFeature`：权益授予、交易监听和恢复。
- `SettingsFeature`：音频、触觉、错误提示、无障碍和隐私。

共享依赖：

- `ContentStore`
- `ProgressStore`
- `EntitlementStore`
- `ArtworkRepository`
- `BlueprintRepository`

## 5. 核心技术实体

### 5.1 内容实体

- `Museum`
  - `id`
  - 本地化元数据
  - `galleryIDs`
- `Gallery`
  - `id`
  - `museumID`
  - `chapterNarrativeID`（叙事映射，不形成另一层内容树）
  - `artworkIDs`
- `Artwork`
  - `id`
  - `museumID`
  - `galleryID`
  - 完整图与受损图资源
  - `repairFragmentIDs`，数量必须为 `1...4`
  - `blueprintID`
- `RepairFragment`
  - `id`
  - `artworkID`
  - 归一化 `region`
  - 修复前后资源
  - `puzzleDefinitionID`
- `PuzzleDefinition`
  - `id`
  - 棋盘、答案、clues、难度数据
- `Blueprint`
  - `id`
  - `artworkID`
  - 生产文件、色号、数量与材料清单引用
- `MuseumBlueprintEntitlement`
  - resolver 在运行时产出的授权值，不属于只读内容 schema
  - `museumID`
  - 授予结果与来源标识

每个 RepairFragment 必须且只能引用一个 PuzzleDefinition；每个 Blueprint 归属于一幅 Artwork。`MuseumBlueprintEntitlementResolving` 是动态授权的唯一读取入口。商品到 Museum entitlement 的静态映射属于 StoreKit/授予配置；已验证交易或促销授予及其离线缓存属于 resolver 实现。内容文件、进度存档和 UI 均不得保存另一份可独立修改的授予状态。

### 5.2 玩家持久化实体

- `RepairFragmentProgress`
- `InProgressSession`
- `StoryState`
- `UserPreferences`

`RepairFragmentProgress` 保存稳定 Fragment ID、puzzle content hash、棋盘状态和完成信息。Artwork 修复状态从其全部 Fragment progress 派生。权益离线缓存是 `EntitlementStore` 的验证缓存，不是玩家进度实体；启动与恢复流程必须通过 resolver 对其校验和刷新。

### 5.3 禁止持久化的派生状态

不得持久化可从当前真相计算的 `artworkRestored` 布尔值、`canUseArtworkBlueprint` 布尔值或 `hasRestorerSeal` 布尔值，避免内容修订、恢复权益或存档迁移后出现双真相。UI 可缓存计算结果，但不能把缓存当持久化来源。

## 6. 完成与权限计算

```swift
enum ArtworkRuleError: Error {
    case invalidRepairFragmentCount(actual: Int)
}

struct ArtworkAccessState {
    let artworkRestored: Bool
    let canUseArtworkBlueprint: Bool
    let hasRestorerSeal: Bool
}

struct ArtworkAccessEvaluator {
    let entitlementResolver: MuseumBlueprintEntitlementResolving

    func evaluate(
        artwork: Artwork,
        completedFragmentIDs: Set<RepairFragment.ID>
    ) throws -> ArtworkAccessState {
        guard (1...4).contains(artwork.repairFragmentIDs.count) else {
            throw ArtworkRuleError.invalidRepairFragmentCount(
                actual: artwork.repairFragmentIDs.count
            )
        }

        let artworkRestored = artwork.repairFragmentIDs
            .allSatisfy(completedFragmentIDs.contains)

        return ArtworkAccessState(
            artworkRestored: artworkRestored,
            canUseArtworkBlueprint: artworkRestored
                || entitlementResolver.hasMuseumBlueprintEntitlement(
                    artwork.museumID
                ),
            hasRestorerSeal: artworkRestored
        )
    }
}
```

唯一公开计算入口 `evaluate` 在返回任何派生值前执行 count 校验，因此空集合不能利用 `allSatisfy` 的真空真值被误判为已恢复。所有已配置 RepairFragments 都参与同一个完成集合。

权限 resolver 只回答 Museum 蓝图库使用权，不写入：

- `RepairFragmentProgress`
- Artwork 修复结果
- Gallery/Chapter 进度
- Museum 进度
- `StoryState`

## 7. 内容输入规范

```text
museums/museum-01/
├── museum.json
└── galleries/
    └── silent-gallery/
        ├── gallery.json
        └── artworks/
            └── artwork-001/
                ├── artwork.json
                ├── restored-artwork.heic
                ├── damaged-artwork.heic
                ├── blueprint/
                │   ├── blueprint.json
                │   ├── production.pdf
                │   └── production.png
                └── fragments/
                    ├── fragment-001/
                    │   ├── fragment.json
                    │   ├── solution.png
                    │   ├── restored.png
                    │   ├── damaged.png
                    │   └── thumbnail.png
                    └── fragment-002/
                        └── ...
```

每个 Artwork 目录必须有 `1–4` 个 Fragment 目录。第 2–4 个只在图上确有对应破损时添加；添加后都必须参与作品完成。

资源规则：

- `solution.png` 精确等于棋盘尺寸，不允许抗锯齿和半透明。
- 左上原点、row-major；黑/透明为空，白为 Filled。
- Fragment `region` 使用归一化坐标，`x/y/width/height` 均在 `[0, 1]`，且区域不得越出 Artwork。
- 受损图必须让每个配置区域可见，其余画面保持完好。
- 小尺寸轮廓必须人工检查。
- 完整制作蓝图只存在于 Artwork 的 blueprint 目录。

## 8. 内容编译与 validator

建立 macOS Swift CLI：`kanaka-content`。

```text
validate-source
→ compile-museums
→ compile-galleries
→ compile-artworks
→ compile-repair-fragments
→ generate-clues
→ solve-and-score
→ validate-assets-and-rights
→ build-content-bundle
→ write-manifest-and-hashes
```

发布前必须校验：

1. 每个 Gallery 恰好归属于一个 Museum。
2. 每个 Artwork 恰好归属于一个 Gallery，且 `museumID` 与 Gallery 一致。
3. 每个 Artwork 的 RepairFragment count 在 `1...4`。
4. 每个 Fragment 区域坐标有效、面积大于零且完整位于 Artwork 内。
5. 每个 Fragment 恰好引用一个 PuzzleDefinition。
6. 所有配置的 Fragment IDs 都进入 Artwork 完成集合，不允许遗漏。
7. Museum、Gallery、Artwork、RepairFragment、PuzzleDefinition、Blueprint 的 ID 在各自全局命名空间唯一，引用无悬空。
8. 答案尺寸、重算 clues 和资源尺寸一致。
9. 每个 puzzle 恰好一个解且可纯逻辑完成。
10. revision、hash、本地化、人工试玩记录和权利记录完整。

任一失败时 CLI 返回非零并拒绝生成发布内容。

## 9. 棋盘、存档与完成事务

### 9.1 渲染与交互

- 单个 Canvas/自定义 UIView，不使用每格一个 View。
- 绘制顺序：背景 → clue → 分隔线 → 格子状态 → 交互预览 → 提示。
- `BoardTransform` 统一逻辑与屏幕坐标转换。
- 拖动起始动作在 transaction 内保持一致。
- 两指手势取消正在进行的绘制。
- 一次拖动形成一个 Undo transaction。

### 9.2 存档

- 每格 2 bit：unknown / filled / excluded / reserved。
- 自动保存采用短节流，进入后台立即 flush。
- 记录 PuzzleDefinition ID 与 content hash。
- 不把每格建成 SwiftData object。

### 9.3 Fragment 完成事务

1. 原子写入对应 `RepairFragmentProgress.completedAt`。
2. 重新读取 Artwork 的全部 `repairFragmentIDs`。
3. 计算并显示 `x/n`。
4. 只更新对应区域的修复视觉。
5. 若 `x == n`，立即触发整幅展示、Blueprint earned access 与 seal UI。
6. Story 事件通过独立叙事规则处理，不能由 entitlement 路径触发。

## 10. 蓝图输出

V1 候选能力：

- App 内高清网格。
- PNG 导出。
- 分页 PDF。
- 色号、逐色数量、总豆数和底板布局。
- 系统 Share Sheet。

具体格式由 A-007 决定。导出文件生成在临时目录，分享完成后清理；文件名不包含用户个人信息。默认不为单个 Repair Fragment 生成生产文件。

## 11. Museum 蓝图库权益

StoreKit 或其他授予来源映射到 `MuseumBlueprintEntitlement(museumID)`。领域层统一使用“拥有/已授予 Museum 蓝图库权益”，不把销售动作写进 Artwork 或 Fragment 模型。

- Museum 1 entitlement 只解析 Museum 1 的 Blueprints。
- Museum 2 使用新的 Museum ID 和权益范围。
- Museum 1 不自动代表未来所有 Museums。
- 一个商品可以授予一个或多个 entitlements；一个 entitlement 也可以由不同商品或促销授予。
- 因此 Museum 是稳定边界，但不等于已确定独立 SKU。
- 商品、定价、免费序章、完整版、主题组合及升级关系全部留给 A-004 验证。

StoreKit 实现仍需监听 transaction updates、验证与恢复权益、使用本地化价格，并确保已验证权益离线可用。

## 12. 测试

### 12.1 核心测试

- clue generation。
- 唯一解、多解、无解。
- 空行、满行、矩形和最大尺寸。
- bitset round trip。
- `GameSession` 操作序列。
- Undo/Redo 与 hint 合法性。
- count 为 0、1、4、5 的边界。
- 全部配置 Fragment 参与完成。
- Museum entitlement resolver。
- entitlement 不修改进度或印章。

### 12.2 内容测试

每次构建运行全量 schema、关系、ID、区域、solver、clue、资源、本地化、hash 和 rights 校验。

### 12.3 UI 测试

- 完成或跳过共同教学后才能选择路径。
- 两条路径层级平等、可自由切换且共享内容。
- Artwork 显示正确 `x/n`。
- 完成 Fragment 只修复一个区域。
- 一个 Fragment 的 Artwork 完成一题立即触发整幅完成。
- 多 Fragment Artwork 仅在最后一题后展示整幅、授予 Blueprint 与印章。
- 拥有 Museum 蓝图库权益时生产文件可用，但所有修复与故事进度保持原值。
- Reduce Motion、Dynamic Type、VoiceOver 关键路径。

### 12.4 性能目标

- 冷启动到可交互主界面目标 2 秒内，不含可跳过开场。
- 棋盘操作目标 60 fps。
- 单 puzzle 解码和恢复目标 200 ms 内。
- 后台/终止不丢进度。
- 不一次加载整个 Gallery 的全部大图。

## 13. CI/CD

### Pull Request

- Swift build。
- Core/Content 单元测试。
- 全量内容 validator。
- App 无签名 build。
- 格式与静态检查。

### Release Candidate

- iPhone/iPad UI tests。
- StoreKit Configuration tests。
- Museum 内容完整性。
- PrivacyInfo、本地化和资源检查。
- Archive 并上传 TestFlight。

Release 使用不可变 tag，记录 App 版本、Museum 内容版本和 commit；证书与 App Store Connect API key 只放 secrets。

## 14. 开发阶段

### M0：规则与范围冻结（1–2 周）

- 固定本文领域层级、完成公式和派生状态边界。
- 确认 Classic Nonogram 规则。
- 为 A-004/A-005 准备验证方案。
- 定义六类内容 schema 与 entitlement resolver protocol。
- 从现有素材中选择 `10` 个用于技术验证。

通过：schema 可表达 1–4 个 Repair Fragments，全部状态和权限只有一个真相来源。

### M1：核心与内容工具（3–4 周）

- `KanakaCore`、clue generator、solver、validator。
- `kanaka-content` CLI。
- 用 `10` 个素材覆盖 1、2、3、4 Fragment 组合。

通过：内容可一键编译；数量、区域、ID、引用或解法错误会阻断构建。

### M2：技术原型（3–4 周，可部分并行）

- App shell、Canvas 棋盘、操作手势、Undo/Redo、SwiftData 存档。
- Museum → Gallery → Artwork 导航。

通过：iPhone/iPad 真机稳定游玩并恢复进度。

### M3：垂直切片（4–6 周）

- 开场、共同教学、平等路径选择、修复室与工坊。
- 建议把 `10` 个技术验证素材组织为四幅 Artwork，Fragment 数量分别为 1、2、3、4。
- 验证每题只修对应区域、`x/n`、最后一题整幅展示、Blueprint 与印章。
- 验证 Museum 蓝图库权益不改变任何进度。
- 音频、触觉与基础无障碍。

通过：四种 cardinality 和双路径闭环均可测试；这四幅 Artwork 不代表首发内容数量。

### M4：Museum 1 完整 V1（8–10 周）

A-005 和垂直切片前使用制作包络：

- `3` 个 Galleries。
- `12–18` 幅 Artworks。
- `20–30` 个 Repair Fragment puzzles。
- 制作基线 `15` 幅 Artworks / `24` 个 puzzles。
- 基线示例分布 `9×1、4×2、1×3、1×4`，仅用于排期和产能估算，不是商店承诺。

同时完成工坊、权益、本地化和权利台账。通过：Feature Complete；全部内容自动验证和人工试玩。

### M5：TestFlight（3–4 周）

- 20–50 人测试教学、触控和双路径理解。
- 100–300 人扩大稳定性测试。
- 验证 A-004/A-005，调整难度、权益描述和范围。
- 准备 App Store metadata。

通过：Release Candidate 连续 7 天无 P0/P1；权益恢复、进度和蓝图导出无阻断。

### M6：审核与发布（2–3 周）

- 提交 App 与最终商品配置。
- 审核备注说明两个入口、内容/权益边界和恢复路径。
- 分阶段或手动发布并监控质量。

## 15. 前四周任务

### 第 1 周

- 建立 Swift Package 与 App 工程。
- 定义 `museum-v1`、`gallery-v1`、`artwork-v1`、`repair-fragment-v1`、`puzzle-definition-v1`、`blueprint-v1`。
- 冻结双路径状态模型与 Museum entitlement protocol。
- 准备 `10` 个技术验证蒙版，并规划 1、2、3、4 Fragment 组合。

### 第 2 周

- clue generator、bitset、solver 初版、validator。
- 棋盘低保真原型。
- Museum/Gallery/Artwork 内容读取。

### 第 3 周

- solver 与内容 CLI。
- 编译技术验证内容。
- entitlement resolver 与派生权限测试。

### 第 4 周

- Canvas 棋盘完整操作和本地存档。
- 简化修复室/工坊切换。
- `x/n`、区域融回、整幅完成和印章。
- 模拟授予 Museum 蓝图库权益，并断言故事与修复进度不变。
- iPhone/iPad 真机验收。

四周成功标准：现有 `10` 个素材只作为技术样本通过完整编译、游玩、存档、恢复与权益测试；不能据此推断 Museum 1 首发规模。

## 16. 团队、周期与发布质量

推荐 1–2 名 iOS 工程师、0.5–1 名游戏/产品设计、0.5–1 名 UI/视觉设计、1–2 名内容设计/关卡 QA，以及兼职音频与后期发布 QA。初步估算：3–5 人并行 20–26 周；单主工程师加兼职设计/内容为 8–12 个月；垂直切片 8–12 周。

发布阻断条件：

- 崩溃、hang 或存档丢失。
- Fragment count、区域或 ID 校验失败。
- 多解、无解或 clue 错误。
- 完成最后一个 Fragment 后未展示整幅、未授予 Blueprint 或印章。
- entitlement 未授予蓝图，或错误推进修复/故事状态。
- 恢复权益失败。
- 主要无障碍路径不可完成。
- 隐私申报与实际行为不一致。
- 素材权利记录不完整。

## 17. 后续路线

- **V1.1**：CloudKit 进度同步、可选日文本地化、Museum 1 内新增内容的权益规则需由 A-004 明确。
- **Museum 2**：新增 Galleries、Artworks、puzzles 与 blueprints；拥有独立 Museum ID 和蓝图库权益边界。
- **后续技术**：彩色 Nonogram、织物/地图/手稿/壁画内容、签名内容下载、根据市场决定 Android。

任何后续 Artwork 都必须明确归属 Museum；不能以无归属的 Chapter 或主题内容绕过 Museum 权益边界。
