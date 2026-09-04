# Kanaka 开发与 App Store 发布规划

> 状态：Frozen v3（V1 范围与技术决策已冻结）
> 目标平台：iOS / iPadOS
> 架构原则：一个 App、两个可切换路径、一个共享内容与权益模型
> V1 固定内容：Museum 1 = `18` Artworks / `30` Fragment puzzles；Artwork Fragment 分布 `10×1 + 5×2 + 2×3 + 1×4`

## 1. 技术决策

| 层 | 选择 |
|---|---|
| 语言 | Swift 6.x |
| UI | SwiftUI |
| 棋盘 | SwiftUI `Canvas` + Core Graphics；复杂手势必要时桥接 UIKit |
| 游戏核心 | 独立 Swift Package：`KanakaCore` |
| 内容协议 | 独立 Swift Package：`KanakaContentKit` |
| 进度协议 | 独立 Swift Package：`KanakaProgress`；内存 Store + Apple 平台 SwiftData adapter |
| 叙事聚合 | 独立 Swift Package：`KanakaStory`；有序证据、单调 milestones 与幂等 reducer |
| 产品应用层 | 独立 Swift Package：`KanakaProductDomain`；组合内容、进度、权益、Blueprint 与 Story |
| 本地存储 | SwiftData；玩家格状态按每格 `UInt8` 压缩为单个 `Data` blob |
| 权益 | StoreKit 2 + 可测试的 entitlement resolver |
| 音视频 | AVFoundation / AVKit |
| 动画 | SwiftUI / Core Animation；SpriteKit 仅按需 |
| 画境运行时 | Apple 原生 3D/2.5D；固定、有限、确定性资产；运行时不调用生成 API |
| 云同步 | CloudKit 仅列入 V1.1，V1 不依赖云同步 |
| 日志与性能 | OSLog、MetricKit、Xcode Organizer |
| 测试 | Swift Testing / XCTest / XCUITest |
| CI/CD | Xcode Cloud 或 GitHub Actions + TestFlight |

V1 使用 Swift 原生，Godot 不进入 V1 技术栈。World Labs 仅可作为离线内容生产工具；生成结果必须人工调整、版本化、优化、验证并随 App 内容发布。建议 Deployment Target 为 iOS 17 / iPadOS 17，并在提交时使用 Apple 要求的最新 Xcode 与 SDK。部署目标不因构建 SDK 更新而自动提高。

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
│   ├── KanakaProgress/
│   ├── KanakaStory/
│   ├── KanakaProductDomain/
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

`bead-gen` 是独立的 2D 拼豆图资产生产项目。它向本项目交付经过验收的 `bead-pattern-v1` JSON、派生预览、调色板、来源与 hashes；App 不依赖其代码、服务或模型。本项目负责 Museum/Gallery/Chapter 编排、3D 画境、破损区域、彩色 Nonogram、恢复反馈、内容包与 QA。

`bead-pattern-v1` JSON 是完整 bead Artwork 网格、palette 与物理规格的上游事实源；`blueprint-v1` 是玩家生产资料的规范事实源。字段级规范见 [`BEAD_PATTERN_SPEC.md`](BEAD_PATTERN_SPEC.md)。固定约束如下：

- 左上原点、row-major；`0 = empty`，非零值为 palette index。
- palette 条目必须提供稳定 `colorId`、`sRGB8`、品牌色号与色卡版本；palette index 只用于文件内寻址，不是长期语义 ID。
- 使用 canonical JSON 计算 SHA-256，计算输入不包含 `contentHash` 字段自身；结果写入 `bead-pattern-v1.contentHash`，作为 **bead asset hash**。
- 分别记录 bead asset hash、Blueprint hash 与 puzzle semantic hash，不能用一个笼统 hash 替代三者。
- PuzzleDefinition 的答案事实源是 JSON semantic grid：每格为 `empty` 或稳定语义 `colorId`。任何 solution PNG 仅可作为派生/debug 资源，不能参与规则、完成判断、迁移或 hash 真相计算。字段、semantic hash 与 solver 发布门统一见 [`PUZZLE_DEFINITION_SPEC.md`](PUZZLE_DEFINITION_SPEC.md)。

Museum 1 的正式范围为 `18` 幅 Artworks / `30` 个 Fragment puzzles，三个 Galleries 分别为 `6 幅/8 题`、`6/10`、`6/12`。18 幅正式作品清单与岗位由 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md) 维护。不再使用候选 10 幅或垂直切片 10 题作为发布范围代号。

## 4. 功能模块

### 4.1 `KanakaCore`

不依赖 SwiftUI、StoreKit 或 SwiftData：

- `PuzzleDefinition`：答案 semantic grid 每格为 `empty | colorId`
- `LineClue(count, colorIndex)`
- `CellState`：`unknown | excluded | filled(colorId)`
- V1 彩色 clue generator：同色段至少隔一空格，异色段可直接相邻
- 唯一、精确彩色解 solver 与纯逻辑验证
- 可解释 hint step
- `GameSession` 状态机
- Undo/Redo transaction
- 完成判断
- 每格 `UInt8` 玩家状态编解码（保留 unknown/excluded 值，其余编码 palette color）
- 难度评分

颜色持久语义以稳定 `colorId` 为准；文件内 `colorIndex` / palette 编码必须经 PuzzleDefinition palette 映射解析，不能把 RGB 或 UI 色值作为答案身份。正式题不使用预填格，必须在无预填条件下通过唯一解与纯逻辑验证；教学、演示与无障碍辅助可例外，预填属于具体游玩 Session 的辅助层，核心 schema 与 solver 必须能够表达、验证并记录预填来源。

内容工具与 App 共用该包，避免编译规则和客户端规则不一致。

### 4.2 `KanakaContentKit`

Codable schema：

- `museum-v1`
- `gallery-v1`
- `artwork-v1`
- `repair-fragment-v1`
- `puzzle-definition-v1`
- `blueprint-v1`

生产审批使用独立的 `curation-manifest-v1`。它不构成第八层运行时内容树，也不参与完成、故事或权益计算；只记录候选状态、策展证据、冻结后的 Gallery 顺序和发布门结果。编译器仅把 `approved` 记录对应的 Artwork 编入内容包，并以 `Gallery.artworkIDs` 的数组顺序作为展示顺序；解锁与 Story progress 仍由独立叙事规则决定。

职责：manifest、资源引用、canonical JSON SHA-256、bead asset/Blueprint/puzzle semantic hashes、schema migration、权利记录引用与跨实体关系校验。`bead-pattern-v1` 的字段级契约与 canonicalization 统一见 [`BEAD_PATTERN_SPEC.md`](BEAD_PATTERN_SPEC.md)，本文件不另建冲突版本。编译产物可以被封装为传输包，但传输包不是产品权益边界。

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
  - `id` 与 `revision`
  - 本地化元数据
  - `galleryIDs`
- `Gallery`
  - `id` 与 `revision`
  - `museumID`
  - `chapterNarrativeID`（叙事映射，不形成另一层内容树）
  - `artworkIDs`
- `Artwork`
  - `id` 与 `revision`
  - `museumID`
  - `galleryID`
  - 完整图与受损图资源
  - `repairFragmentIDs`，数量必须为 `1...4`
  - `blueprintID`
- `RepairFragment`
  - `id` 与 `revision`
  - `artworkID`
  - 归一化 `region`
  - 修复前后资源
  - `puzzleDefinitionID`
- `PuzzleDefinition`
  - `id` 与 `revision`
  - 棋盘尺寸与 palette 映射
  - JSON semantic grid：每格 `empty | colorId`
  - 行列 `LineClue(count, colorIndex)`
  - puzzle semantic hash、难度与纯逻辑 solver 报告
  - 可选 prefilled constraints（正式题禁止配置；仅教学/演示/无障碍辅助可例外，并记录来源）
- `Blueprint`
  - `id`
  - `artworkID`
  - `sourceBeadAsset = { assetId, revision, contentHash }`
  - 完整 grid、palette、材料统计、物理规格与 export rules
  - `revision` 与 Blueprint hash
- `MuseumBlueprintEntitlement`
  - resolver 在运行时产出的授权值，不属于只读内容 schema
  - `museumID`
  - 授予结果与来源标识
- `CurationManifest`（`curation-manifest-v1`，生产审批附件，不进入运行时领域状态）
  - `museumID`
  - `records[]`；每条以 `candidateAssetID` 为生产主键，导入后唯一映射到 `artworkID`
  - 章节字段：`galleryID`、`chapterBeatID`、`sequenceIndex`、`primaryNarrativeRole`、可选 `secondaryNarrativeRole`、`revealLevel`
  - 负担与世界字段：`targetArtworkLoadBand`、`worldMode`、`restorationFeedback`
  - `fragmentTargets[]`：`fragmentID`、`targetDifficultyBand`、`solverScore`、`estimatedMinutes`、`damageSemantic`
  - 审批字段：`rightsStatus`、`provenance`、`curationScore`、`curationStatus`、`evidenceRefs[]`、`productionRisks[]`

字段枚举、状态条件与必填阶段以 `CONTENT_CURATION.md` 6.4 为准。`approved` 记录必须有 `artworkID`、Gallery/beat/顺序、至少一个 fragment target、`rightsStatus=cleared` 和完整证据；`2.5d / limited3d` 还必须先达到 `worldValidated`。

`Gallery.artworkIDs` 是编译后的展示顺序，不直接代表 Story 解锁条件。`CurationManifest` 只决定哪些内容可编译和以什么顺序展示；不能修改 RepairFragment progress、StoryState、Blueprint access 或 entitlement。

每个 RepairFragment 必须且只能引用一个 PuzzleDefinition；编译后的运行时内容包中，每个 PuzzleDefinition 也必须被且仅被一个 RepairFragment 引用，禁止孤儿题目或跨 Fragment 共享题目身份。每个 Blueprint 归属于一幅 Artwork。`MuseumBlueprintEntitlementResolving` 是动态授权的唯一读取入口。商品到 Museum entitlement 的静态映射属于 StoreKit/授予配置；已验证交易或促销授予及其离线缓存属于 resolver 实现。内容文件、进度存档和 UI 均不得保存另一份可独立修改的授予状态。

### 5.2 玩家持久化实体与内容迁移边界

- `RepairFragmentProgress`
- `InProgressSession`
- `StoryState`
- `UserPreferences`

`StoryState` 将 Museum 1 Canon 建模为一组**独立、单调、可审计的 milestones**，不得用 Gallery 展示顺序、Artwork 修复布尔值或 entitlement 代替：

| Milestone | 唯一叙事含义 | 必要前置 |
|---|---|---|
| `technicalChainRestored` | Chapter 1 六幅已按顺序恢复“研究员身份 → 接驳锚点 → 地下实验室位置 → 校准/维护记录”的完整窄技术知识链 | 对应证据事件全部成立 |
| `bridgeLocated` | 已在博物馆地下确认被误作未知旧扫描设备的实体机器就是灾前画桥 | `technicalChainRestored` |
| `bridgeBrieflyStarted` | 主角凭身体记忆让遗机短暂启动并收到接驳回声；没有完成接驳或进入画境 | `bridgeLocated` |
| `bridgeRebooted` | Chapter 2 的诊断、时间同步、路径、锚点重校准与连续性/安全验证完成后，A12 入场事件在开放可探索画境前完成遗机灾后重启 | `bridgeBrieflyStarted` |
| `firstPostCollapseFullEntryCompleted` | 主角完成 A12 同一 session 的三道修复并安全离开，达成灾后首次、也是其本人首次完整进入真实画境；不表示人类首次入画 | `bridgeRebooted` |
| `firstGenerationPurgeRevealed` | Chapter 3 证据证明灾前第一代计划曾被主动语义清除，并以档案、生命体征中止、空操作位等非正面方式确认第一代入画者在画境遇害、现实身体同步死亡 | `firstPostCollapseFullEntryCompleted` |
| `newOperatorDetected` | Museum 1 结尾，对方识别到按清除逻辑本应不存在的新操作员 | `firstGenerationPurgeRevealed` |

milestone 写入必须幂等；重复事件不重复触发演出，越过前置的事件必须拒绝并记录内容错误。Chapter 1 离场最多到 `bridgeBrieflyStarted`，Chapter 2 离场最多到 `firstPostCollapseFullEntryCompleted`，Chapter 3/Museum 1 末依次达到 `firstGenerationPurgeRevealed` 与 `newOperatorDetected`。这些状态只由独立叙事聚合器根据已验证的 Canon 证据事件推进；当代团队发现、校准和重启灾前机器，不得产生“发明画桥”状态，主角也不得产生“人类首位入画者”状态。

`RepairFragmentProgress` 保存稳定 Fragment ID、PuzzleDefinition ID、puzzle revision、puzzle semantic hash、每格 `UInt8` 玩家状态和完成信息。Artwork 修复状态从其全部 Fragment progress 派生。权益离线缓存是 `EntitlementStore` 的验证缓存，不是玩家进度实体；启动与恢复流程必须通过 resolver 对其校验和刷新。

内容迁移的安全边界已经冻结：

1. 只改变元数据或派生预览，且 puzzle semantic hash 不变：不影响 puzzle progress。
2. semantic grid、palette 语义映射或任何会改变精确答案的内容发生变化：发布新的 puzzle revision 与 puzzle semantic hash，不覆盖旧答案身份。
3. revision/hash 不匹配时，绝不静默把旧 `UInt8` 状态套用到新答案。

具体玩家记录政策仍待最终确认。当前候选方案是：进行中的旧 revision 重置并在进入时提示；已完成旧 revision 保留为 `completedLegacyRevision`、继续认可 Artwork 完成并允许重玩新 revision。该候选不构成冻结通过标准；确认后必须补充显式迁移版本、可测试转换和玩家可见说明。

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
├── curation-manifest.json
└── galleries/
    └── silent-gallery/
        ├── gallery.json
        └── artworks/
            └── artwork-001/
                ├── artwork.json
                ├── bead-pattern-v1.json
                ├── restored-artwork.heic
                ├── damaged-artwork.heic
                ├── blueprint/
                │   ├── blueprint.json
                │   ├── production.png
                │   └── materials.json
                └── fragments/
                    ├── fragment-001/
                    │   ├── fragment.json
                    │   ├── puzzle-definition.json
                    │   ├── solution.debug.png
                    │   ├── restored.png
                    │   ├── damaged.png
                    │   └── thumbnail.png
                    └── fragment-002/
                        └── ...
```

每个 Artwork 目录必须有 `1–4` 个 Fragment 目录。第 2–4 个只在图上确有对应破损时添加；添加后都必须参与作品完成。

资源与事实源规则：

- `bead-pattern-v1.json` 是完整 bead Artwork 网格、palette 与物理规格的上游事实源；`blueprint/blueprint.json` 是玩家生产资料的规范事实源；两者契约见 [`BEAD_PATTERN_SPEC.md`](BEAD_PATTERN_SPEC.md)。
- PuzzleDefinition JSON 中的 semantic grid 是谜题答案唯一事实源，每格仅为 `empty` 或稳定 `colorId`。
- 坐标左上原点、row-major；bead grid 使用 `0=empty`、非零 palette index，并通过 palette 条目的稳定 `colorId`、`sRGB8`、品牌色号与色卡版本解析。
- `solution.debug.png`、预览、缩略图和导出 PNG 都是派生资源，可删除重建；不得作为答案、迁移、完成判断或 semantic hash 的输入。
- canonical JSON SHA-256 的输入排除各自 hash 字段；bead asset、Blueprint 与 puzzle semantic hashes 分开记录。
- Fragment `region` 使用归一化坐标，`x/y/width/height` 均在 `[0, 1]`，且区域不得越出 Artwork。
- 受损图必须让每个配置区域可见，其余画面保持完好。
- 小尺寸彩色轮廓与颜色可区分性必须人工检查。
- 完整制作蓝图只存在于 Artwork 的 blueprint 目录；分页 PDF 若提供也只是派生导出，不是事实源。

## 8. 内容编译与 validator

建立 macOS Swift CLI：`kanaka-content`。

```text
validate-source
→ validate-curation
→ validate-bead-pattern-and-canonical-hashes
→ compile-museums
→ compile-galleries
→ compile-artworks
→ compile-repair-fragments
→ resolve-semantic-color-grids
→ generate-color-clues
→ solve-and-score-exact-color-solutions
→ validate-assets-and-rights
→ build-content-bundle
→ write-manifest-and-separated-hashes
```

发布前必须校验：

1. 每个 Gallery 恰好归属于一个 Museum。
2. 每个 Artwork 恰好归属于一个 Gallery，且 `museumID` 与 Gallery 一致。
3. 每个 Artwork 的 RepairFragment count 在 `1...4`。
4. 每个 Fragment 区域坐标有效、面积大于零且完整位于 Artwork 内。
5. 每个 Fragment 恰好引用一个 PuzzleDefinition；每个编入包的 PuzzleDefinition 也恰好归属于一个 Fragment，不允许孤儿或共享题目身份。
6. 所有配置的 Fragment IDs 都进入 Artwork 完成集合，不允许遗漏。
7. Museum、Gallery、Artwork、RepairFragment、PuzzleDefinition、Blueprint 的 ID 在各自全局命名空间唯一，引用无悬空。
8. `bead-pattern-v1` 满足左上原点、row-major、`0=empty`、palette index 与稳定 `colorId` 映射；canonical JSON hash 可重算且不包含 `contentHash` 自身。
9. Puzzle semantic grid 只含 `empty | colorId`，尺寸与 palette 引用有效；重算的 `(count, colorIndex)` clues 与 JSON 答案一致，同色段至少隔一空格、异色段允许直接相邻。
10. 每个正式 puzzle 在无预填条件下恰好一个精确彩色解且可纯逻辑完成；若含预填，必须属于明确标记的教学、演示或无障碍辅助例外。
11. bead asset、Blueprint 与 puzzle semantic hashes 分离且完整；revision、迁移信息、本地化、人工试玩记录和权利记录完整。
12. Museum 1 编译结果必须恰为 18 Artworks / 30 Fragments，Fragment 分布为 `10×1 + 5×2 + 2×3 + 1×4`，Gallery 计数依次为 `6/8`、`6/10`、`6/12`。
13. `playable-experience-v1` sidecar 必须精确覆盖已编入的 Museum/Gallery/Artwork/Fragment IDs，包含非空默认 locale、完整 intro、唯一 `5×5` tutorial Puzzle 引用和修复室/工坊两个入口；展示 sidecar 不得进入 Puzzle、bead、Blueprint 或 progress identity/hash。

机器校验之外，发布内容还必须存在与 Artwork 一对一映射的 `curation-manifest-v1` approved 记录：`candidateAssetID`、`artworkID`、`galleryID`、`chapterBeatID`、`sequenceIndex`、主要叙事岗位、整幅负担带、`fragmentTargets`、`worldMode`、`rightsStatus=cleared` 与完整 `evidenceRefs`。CLI 验证字段、枚举、条件必填、唯一映射、同 Gallery 顺序和引用完整性；叙事匹配、恢复辨识和画境体验由 `CONTENT_CURATION.md` 定义的人工审查负责。

任一失败时 CLI 返回非零并拒绝生成发布内容。

## 9. 棋盘、存档与完成事务

### 9.1 渲染与交互

- 单个 Canvas/自定义 UIView，不使用每格一个 View。
- 绘制顺序：背景 → clue → 分隔线 → 格子状态 → 交互预览 → 提示。
- `BoardTransform` 统一逻辑与屏幕坐标转换。
- 拖动起始动作在 transaction 内保持一致。
- 两指手势取消正在进行的绘制。
- 一次拖动形成一个 Undo transaction。
- `GameSession.applyBatch` 原子校验并提交一次点击或拖动；重复坐标、越界格、未知颜色或作者预填锁定格使整批失败。
- no-op 不写入历史；新 transaction 清空 Redo；Undo/Redo 在本次运行内不限次数，不跨启动持久化。
- 答案颜色格必须精确匹配稳定 `colorId`；答案 empty 可由 `unknown` 或 `excluded` 满足，但任何 filled 都不满足。
- authored prefill 与已实际交付的 hint/dynamic reveal/accessibility prefill 形成单调 assistance history；Undo 不恢复 `completedWithoutHints` 资格。

### 9.2 存档

- `cell-state-codec-v1` 每格使用一个 `UInt8`：`0 = unknown`、`1 = excluded`、`2...255 = filled(colorIndex = byte - 1)`；palette 最多 `254` 色，并必须解析回稳定 `colorId`。
- 旧的两位元状态格式不能表达 V1 多色玩家状态；cell count、palette 连续索引、未知 colorId 与越界 byte 必须严格拒绝，不能静默降级为 unknown。
- `KanakaProgress` 以 `ProgressRecordKey(fragmentID + puzzleID + revision + semanticHash)` 标识记录；不同 revision/hash 并存，不覆盖或删除旧记录。
- 自动保存采用可注入的短节流（默认 `300 ms`），只提交最新 snapshot；进入后台由上层显式 `await flush()`。
- 每次提交携带单调 generation；Store 幂等接受同 generation，拒绝旧 generation，避免延迟自动保存覆盖更新状态或完成状态。
- 记录 PuzzleDefinition ID、revision、puzzle semantic hash 与 palette 语义映射。
- 恢复时必须先验证 codec version、PuzzleDefinition ID、revision、semantic hash、尺寸/cell count 和 palette 语义映射；不匹配时禁止解码或载入旧格子状态，并进入明确的迁移决策路径。
- semantic hash 相同但 revision 不同也先返回独立 migration decision，不静默恢复；玩家记录政策确认前，不自动重置或改写旧记录。
- snapshot 保存当前 cells 与 assistance history；Undo/Redo history 仅内存，不进入持久化。
- 不把每格建成 SwiftData object。

### 9.3 Fragment 完成事务

1. 通过一个 Store 操作原子写入对应 Fragment 的最终 snapshot 与 `completedAt`；SwiftData adapter 在同一个 `ModelContext.save()` 中提交两者。
2. 以 Artwork 的全部 `repairFragmentIDs` 和当前精确 `ProgressRecordKey` 重新计算完成集合；同一 Fragment 的其他 revision/hash 不计入当前 `x/n`。
3. 返回并显示严格当前 identity 的 `x/n` completion receipt。
4. 只更新对应区域的修复视觉。
5. 若 `x == n`，立即触发整幅展示、Blueprint earned access 与 seal UI。
6. Fragment/Artwork 完成只向独立叙事聚合器提交带证据 ID 的 Canon 事件；聚合器校验内容顺序与 milestone 前置后，才幂等推进 `StoryState`。
7. entitlement resolver、购买/恢复权益、Blueprint 访问、展示顺序和跳转 UI 均不得提交 Canon 事件，也不得直接或间接触发 `technicalChainRestored`、`bridgeLocated`、`bridgeBrieflyStarted`、`bridgeRebooted`、`firstPostCollapseFullEntryCompleted`、`firstGenerationPurgeRevealed` 或 `newOperatorDetected`。

当前 completion receipt 刻意只认可当前精确 identity。旧 revision 是否继续认可 Artwork 完成仍属于待冻结的玩家迁移政策；在政策确认前，不自动删除、覆盖、重置或认可 legacy completion。

`KanakaProductDomain` 采用确定性 reconciliation 连接 durable completion 与 `KanakaStory`：一次 exact-current batch progress snapshot 为全 catalog 构造候选，再按 Story rule 顺序推进可用前缀；先完成的后序内容会保留在 durable progress 中，并在前序证据出现后自动收敛。Fragment 与 Artwork occurrence 使用包含 `fragmentID / puzzleID / revision / semanticHash` 的版本化长度前缀 canonical bytes 计算 SHA-256；Artwork 时间取所有构成 Fragment 的 durable `completedAt` 最大值，因此重放 byte-for-byte 稳定。completion mapping 在 ProductFlow 初始化时校验 catalog 实体、规则 source kind 与 evidence 唯一性，narrative/bridge API 不能构造 completion source。

`StoryStateStore.apply` 是 load → reduce → persist 的原子事务边界；内存 actor 在一个隔离区内完成，Apple `SwiftDataStoryStateStore` 也在单 actor、无 suspension 的 fetch → reduce → encode → `ModelContext.save()` 中完成并在失败时 rollback。该保证仅覆盖 App 内唯一 writer；未来若引入 extension 或多进程 writer，必须增加持久化 CAS/事务，不能依赖 actor。Progress mutation 在 `PuzzleSessionController` 内自动提交 autosave，Undo/Redo 同样在 mutation 后提交；`flush` 仍是进入后台或离开场景前的明确 durability boundary。Artwork 普通查询使用 Store batch snapshot；完成结果直接由同一 completion receipt 的 exact-key `completedAt` map 派生，避免 receipt 与 Artwork state 观察不同并发时刻。

生产 bead/Blueprint hash 直接对原始 JSON 移除顶层 hash 字段后执行 RFC 8785 JCS canonicalization + SHA-256，不从解码后的 Swift semantic object 重构 hash 输入。canonicalizer 直接把 JSON number 解析为 IEEE-754，再按 ECMAScript 阈值输出 shortest round-trip 表示，并拒绝 duplicate object members；CLI 固定 key/string/number conformance vectors。validator 同时拒绝 RGB 越界、generator 空 identity、board/grid 覆盖不一致、重复材料和 export dimension overflow。生产包必须包含唯一 `production-assets-v1` manifest：所有 bead 与 Blueprint revision 以完整 `(ID, revision)` 共存，manifest 通过 revision + hash 为每个稳定 ID 显式选择一个 active 版本；升级与回滚都不能按最大 revision 静默切换。受保护的 Blueprint payload 与 export-plan 构造保持在 ProductDomain SPI 后，App 正常入口只返回经 `BlueprintUseService.openBlueprint` 授权的 `AuthorizedBlueprint`。

这些选择不冻结未来 outbox schema，也不允许 entitlement、Blueprint 浏览或导出产生 Canon evidence。当前 Linux gate 无法编译 SwiftUI/SwiftData/StoreKit/Core Graphics 等 Apple 分支；其结果必须明确视为 Xcode/iOS 17/macOS 14 待验证项。

## 10. Blueprint V1 输出

V1 必须提供：

- App 内高清彩色网格；
- PNG 导出；
- 材料清单（稳定 `colorId`、品牌色号/色卡版本、逐色数量、总豆数和底板布局）；
- 系统 Share Sheet。

分页 PDF 可在 V1 提供，也可延后至 V1.1；无论何时提供都只是从 `bead-pattern-v1` JSON 与 Blueprint semantic data 派生的导出格式，不能成为事实源或其他必选输出的前置依赖。

导出文件生成在临时目录，分享完成后清理；文件名不包含用户个人信息。默认不为单个 Repair Fragment 生成生产文件。

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

- 彩色 clue generation 与 `(count, colorIndex)` 编解码。
- 同色段强制至少一空格、异色段直接相邻。
- 唯一精确彩色解、多解、无解与纯逻辑可解性。
- 空行、满行、矩形、最大尺寸与多颜色边界。
- 每格 `UInt8` 玩家状态 round trip、palette 映射、保留值和非法值拒绝。
- canonical JSON SHA-256 可重算且排除 `contentHash` 自身。
- bead asset / Blueprint / puzzle semantic hash 相互独立。
- 仅元数据/预览更新保持 puzzle progress；答案 revision 更新绝不静默复用旧状态。具体的重置/legacy 保留测试在玩家迁移政策确认后加入。
- `GameSession` 操作序列。
- 首次体验 reducer 只允许 `intro → tutorial completed/skipped → initial route` 单调转换；教学使用独立 `GameSession`，不得写 Fragment Progress、恢复 Artwork、授予 seal/Blueprint 或提交 Story evidence。
- `playable-experience-v1` 的本地化、实体展示与完成文案必须精确覆盖 catalog，展示 revision 不改变游戏事实 identity/hash。
- Undo/Redo 与 hint 合法性。
- count 为 0、1、4、5 的边界。
- 全部配置 Fragment 参与完成。
- Museum entitlement resolver。
- entitlement 不修改进度、印章或任何 `StoryState` milestone；购买、恢复购买、离线权益缓存刷新和 Blueprint 直接访问均不得产生 Canon 事件。
- `StoryState` milestones 各自可独立持久化、幂等 round trip，重复证据不重复触发演出。
- 正序测试：`technicalChainRestored → bridgeLocated → bridgeBrieflyStarted → bridgeRebooted → firstPostCollapseFullEntryCompleted → firstGenerationPurgeRevealed → newOperatorDetected` 逐步成功，每步只改变目标 milestone。
- 逆序/跳步测试：任一 milestone 缺少直接或间接前置时拒绝；尤其 Chapter 1 事件不能设置 `bridgeRebooted` 或 `firstPostCollapseFullEntryCompleted`，A12 前五幅准备证据不足时不能设置 `bridgeRebooted` 或打开完整接驳 session，A18 最后一个 Fragment 前不能设置 `firstGenerationPurgeRevealed` 或 `newOperatorDetected`。
- 文案语义测试：`firstPostCollapseFullEntryCompleted` 只表示“灾后/主角首次完整进入”，不得派生“人类首次入画”；`bridgeRebooted` 不得派生“当代团队发明画桥”。

### 12.2 内容测试

每次构建运行全量 schema、关系、ID、区域、solver、clue、资源、本地化、hash 和 rights 校验，并运行 Museum 1 Canon 顺序 validator：

- G1 A01–A06 只能按“研究员身份 → 接驳锚点 → 地下实验室位置 → 校准/维护记录 → 遗机短启动/回声”提供证据，离场不得完整接驳；
- G2 A07–A11 必须覆盖重启准备；准备证据齐全后，A12 入场事件先标记 `bridgeRebooted` 才能开放同一可探索 session，三题全部完成并安全离开后才标记 `firstPostCollapseFullEntryCompleted`；
- G3 A13–A17 必须逐步建立第一代团队、真实接驳、画境内遇害/现实同步死亡及主动清除的交叉证据，但不得提前完成正式揭示；A18 最后一个 Fragment 汇总证据后先标记 `firstGenerationPurgeRevealed`，再由接驳端识别事件标记 `newOperatorDetected`；
- 任何内容不得把当代团队定义为发明者、把主角定义为人类首位入画者，或用战斗/正面死亡场面承担修复反馈。

### 12.3 UI 测试

- 完成或跳过共同教学后才能选择路径。
- 两条路径层级平等、可自由切换且共享内容。
- Artwork 显示正确 `x/n`。
- 完成 Fragment 只修复一个区域。
- 一个 Fragment 的 Artwork 完成一题立即触发整幅完成。
- 多 Fragment Artwork 仅在最后一题后展示整幅、授予 Blueprint 与印章。
- 拥有 Museum 蓝图库权益时生产文件可用，但所有修复与故事进度保持原值。
- Chapter 1 末只播放遗机短启动/接驳回声，不能进入可探索画境；Chapter 2 A12 前置未满足时 UI 不允许设置 `bridgeRebooted`，也不打开完整接驳 session。
- A12 入场事件先显示遗机完成灾后重启，再开放同一可探索 session；三题全部完成并安全离开后，才显示主角完成灾后及本人首次完整进入。Chapter 3/A18 最后一个 Fragment 后按顺序显示第一代遇害/同步死亡与计划主动清除的组合证据获证，再显示新操作员被识别。
- 第一代死亡通过档案、生命体征与空操作位等非正面 UI 呈现；修复和画境交互均无战斗态。
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
- 冻结 V1 彩色 Nonogram 规则：`(count,colorIndex)`、同色分隔、异色相邻、唯一精确彩色解和纯逻辑。
- 为 A-004 准备商业验证方案；冻结正式题无预填发布门，保留教学/演示/无障碍辅助例外。
- 定义六类运行时内容 schema、`bead-pattern-v1` 接口、生产用 `curation-manifest-v1` 与 entitlement resolver protocol。
- 按 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md) 建立全部 18 幅 Artwork 的生产台账和 30 个 Fragment 目标。
- 定义独立、单调的 `StoryState` milestones、Canon 事件证据、前置顺序、幂等写入与 entitlement 隔离。

通过：schema 可表达彩色语义答案、1–4 个 Repair Fragments、独立 hashes 与 revision 安全边界；`StoryState` 可独立表达 `technicalChainRestored`、`bridgeLocated`、`bridgeBrieflyStarted`、`bridgeRebooted`、`firstPostCollapseFullEntryCompleted`、`firstGenerationPurgeRevealed`、`newOperatorDetected`，且顺序/跳步/重复/entitlement 隔离测试通过；全部状态和权限只有一个真相来源。

### M1：核心与内容工具（3–4 周）

- `KanakaCore` 彩色 clue generator、精确彩色 solver、纯逻辑验证与 validator。
- `kanaka-content` CLI、canonical JSON/hash 与 `bead-pattern-v1` 导入边界。
- 建立覆盖 1、2、3、4 Fragment cardinality 的编译 fixtures；其中英雄画作 fixture 固定为 3 个 Fragment 与 `5×5/10×10/15×15` 彩色题。

通过：内容可一键编译；颜色语义、数量、区域、ID、hash、引用或解法错误会阻断构建。

### M2：技术原型（3–4 周，可部分并行）

当前 Apple composition 代码已具备 Bundle catalog、Museum → Gallery → Artwork → Fragment 导航、可操作 `5×5` reference board、mutation autosave、Undo/Redo、completion、SwiftData Progress/Story stores、StoreKit 外部映射、授权后 Blueprint PNG/材料导出、Share Sheet 与 scene flush。Bundle 仍使用 synthetic development fixture，且 Linux 只能编译 sentinel。以下 Apple 工作仍需 Xcode/真机完成：

- 建立签名 iOS/iPadOS App host target，编译并修复全部 SwiftUI/SwiftData/StoreKit/Core Graphics 条件分支。
- 将 reference Grid 棋盘升级/验证为适合 `20×20/25×25` 的 Canvas 或虚拟化渲染，补齐拖拽事务、缩放/平移与 60 fps 门。
- 用 SwiftData reopen/migration、StoreKit Configuration、PNG golden pixel、Share Sheet、scene suspension 和 accessibility UI tests 验证 adapters。

通过：iPhone/iPad 真机稳定游玩并恢复进度。

### M3：垂直切片（4–6 周）

- 开场、共同教学、平等路径选择、修复室与工坊。
- 接入代表 1–4 cardinality 的 fixtures，验证双路径、完成反馈与 Canon 叙事体验。
- 垂直切片从 Chapter 1 离场存档开始：已具备 `technicalChainRestored`、`bridgeLocated` 与 `bridgeBrieflyStarted`，且明确只发生过遗机短启动/接驳回声，没有完整进入。
- 用 A07–A11 fixture 依次验证遗机诊断、时间同步、接驳路径、锚点重校准与连续性/安全验证；缺任一证据都不能推进灾后重启。
- 完成一幅《潮汐城的归桥》英雄作品：正好 3 Fragment，使用 `5×5`、`10×10`、`15×15` 彩色题；A07–A11 证据齐全后，A12 入场事件先设置 `bridgeRebooted`，再开放同一有限、固定、确定性 3D session；三处修复在该 session 内逐题恢复对应区域，累计移动、观察和热点交互预算为 `3–5` 分钟，不含解题与暂停。完成三题并安全离开 session 后才设置 `firstPostCollapseFullEntryCompleted`，文案限定为灾后及主角本人首次完整进入，不得表述成人类首次入画或当代发明。
- 验证每题只修对应区域、`x/n`、最后一题整幅展示、Blueprint 与印章。
- 若性能、舒适度或无障碍门失败，英雄画境回退为 2.5D，再失败则回退固定观察点；谜题和叙事证据不变。
- 验证 Museum 蓝图库权益不改变任何进度。
- 音频、触觉与基础无障碍。

通过：四种 cardinality、双路径闭环与英雄画境可测试；3D 或其正式回退方案通过性能与无障碍门；Chapter 1 短启动状态不能越级完整进入，A07–A12 的重校准/重启顺序测试通过，且 entitlement 操作前后七个 Story milestones 完全不变。

### M4：Museum 1 完整 V1（8–10 周）

固定交付：

- `3` 个 Galleries。
- `18` 幅 Artworks。
- `30` 个 Repair Fragment puzzles。
- Artwork Fragment 分布 `10×1 + 5×2 + 2×3 + 1×4`。
- Gallery 分布依次为 `6 幅/8 题`、`6/10`、`6/12`。
- 正式清单与岗位以 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md) 为准。

同时完成工坊、V1 必选 Blueprint 输出、权益、本地化和权利台账。

Museum 1 Canon 验收同时要求：

- G1 六幅只恢复窄技术链，并以地下遗机被确认、身体记忆短启动和接驳回声离场；不得完整进入；
- G2 A07–A11 完成重启准备，A12 入场事件先完成灾后重启再开放可探索 session；三题全部完成并安全离开后，主角的灾后首次完整进入才成立，且明确当代团队不是发明者、主角不是人类首位入画者；
- G3 A13–A17 以档案、生命体征、空操作位等非正面证据逐步建立第一代团队、遇害/同步死亡与清除审计链，但不提前完成正式揭示；A18 最后一个 Fragment 后先使 `firstGenerationPurgeRevealed` 成立，再触发 `newOperatorDetected`；
- 修复、回声、接驳与画境探索保持非战斗，entitlement 全程不能推进任何 milestone。

通过：Feature Complete；固定计数、全部内容自动验证和人工试玩均通过；七个 `StoryState` milestones 的正序、禁止跳步、幂等、章节上限和 entitlement 隔离验收全部通过。

### M5：TestFlight（3–4 周）

- 20–50 人测试教学、触控和双路径理解。
- 100–300 人扩大稳定性测试。
- 验证 A-004 的商品表达，并验证固定 `18/30` 内容的产能、难度与质量门；不通过测试静默改变已冻结范围。
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
- 实现 [`BEAD_PATTERN_SPEC.md`](BEAD_PATTERN_SPEC.md) 的 `bead-pattern-v1` 解析、canonical JSON 与三类 semantic hashes。
- 将 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md) 的 18 幅/30 题固定清单导入生产台账，并建立 1–4 Fragment fixtures。

### 第 2 周

- 彩色 clue generator、`UInt8` 玩家状态编码、精确彩色 solver 初版、validator。
- 棋盘低保真原型。
- Museum/Gallery/Artwork 内容读取。

### 第 3 周

- solver、纯逻辑证明与内容 CLI。
- 编译技术验证内容，验证 JSON/PNG 事实源边界与 revision 迁移。
- entitlement resolver 与派生权限测试。

### 第 4 周

- 彩色 Canvas 棋盘完整操作和本地存档。
- 简化修复室/工坊切换。
- `x/n`、区域融回、整幅完成和印章。
- 模拟授予 Museum 蓝图库权益，并断言故事与修复进度不变。
- iPhone/iPad 真机验收。

四周成功标准：彩色核心、`bead-pattern-v1`、三类 hashes、revision 迁移和 1–4 cardinality fixtures 通过完整编译、游玩、存档、恢复与权益测试；Museum 1 的固定 18 幅/30 题台账无计数或引用漂移。

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

- **V1.1**：CloudKit 进度同步、可选日文本地化、可选分页 PDF，以及 Museum 1 内新增内容的权益规则（需由 A-004 明确）。
- **Museum 2**：新增 Galleries、Artworks、彩色 puzzles 与 blueprints；拥有独立 Museum ID 和蓝图库权益边界。
- **后续技术**：织物/地图/手稿/壁画内容、签名内容下载、根据市场决定 Android；任何新题型都不得破坏 V1 彩色 semantic grid 与 revision 兼容边界。

任何后续 Artwork 都必须明确归属 Museum；不能以无归属的 Chapter 或主题内容绕过 Museum 权益边界。
