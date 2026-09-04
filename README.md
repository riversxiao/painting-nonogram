# Kanaka / Painting Nonogram

Kanaka 是一款面向 iPhone 与 iPad 的叙事型彩色 Nonogram 游戏。玩家在“长夜”后的文明修复署工作，通过行列线索修复作品中真实受损的局部，并获得真正可以制作的整幅拼豆蓝图。

## 一个 App，两条平等路径

首次启动先介绍“长夜”和文明修复署，随后用一局可明确跳过的 `5×5` 共同教学解释彩色 Nonogram。完成或跳过教学后，用户可选择初始落点，并随时切换：

- **学徒成长 / 修复室**：解开彩色 Nonogram、恢复作品、推进故事并亲手获得蓝图。
- **专业画师 / 拼豆工坊**：使用已获得或已被授予权限的蓝图，查看色号、材料并导出制作文件，也可随时回到修复室。

两条路径共享内容、进度与权益。蓝图库权益只改变 Blueprint access；不会完成谜题、改变作品状态、推进 Gallery/Chapter 或 Museum，不会触发、满足或完成任何 Story milestone，也不会授予“亲手修复”印章。

## 内容与完成规则

```text
Museum
└─ Gallery（承载 Chapter 叙事；Museum 1 为 1:1 映射）
   └─ Artwork
      └─ 1–4 Repair Fragments
         └─ 每个 Fragment 对应一个真实破损区域和一个彩色 Nonogram
```

每幅 Artwork 大部分保持完好，只为实际存在的 `1–4` 个局部破损配置 Repair Fragment。第 2–4 个仅在确有破损时存在；一旦配置，每个 Fragment 都必须完成。

- 每完成一个 Fragment，只修复对应区域，并显示 `x/n`。
- 完成最后一个 Fragment 后，立即展示整幅修复作品、授予整幅可制作拼豆蓝图与“亲手修复”印章。
- 默认不奖励局部可制作蓝图。
- 只有一个 Fragment 的 Artwork，完成一题就立即触发整幅完成流程。

权限统一为：

```text
require 1 <= artwork.fragments.count <= 4
artworkRestored = artwork.fragments.allSatisfy(isCompleted)
canUseArtworkBlueprint = artworkRestored OR hasMuseumBlueprintEntitlement(artwork.museumID)
hasRestorerSeal = artworkRestored
```

专业蓝图库以 Museum 为内容与权益边界。拥有或被授予某 Museum 的蓝图库权益，可使用该馆的专业蓝图，但不承诺覆盖未来 Museum。Museum 2 是新增 Galleries、Artworks、puzzles 与 blueprints 的新范围。具体 SKU、定价及免费内容组合仍由 A-004 验证。

## Museum 1 V1 冻结范围

Museum 1 固定为：

- `3` 个 Galleries：静默展厅、烟痕画廊、水下档案。
- `18` 幅 Artworks、`30` 个 Repair Fragment puzzles。
- Fragment 精确分布：`10×1 + 5×2 + 2×3 + 1×4 = 30`。
- Gallery 精确分配：静默展厅 `6 Artworks / 8 puzzles`、烟痕画廊 `6 / 10`、水下档案 `6 / 12`。
- 每个 Gallery 承载一个 Chapter；Museum 1 使用 1:1 映射。

V1 采用彩色 Nonogram。每条 clue 为 `(count, colorIndex)`；同色段之间至少间隔一个空格，异色段可以相邻。玩家格状态为 `unknown / excluded / filled(colorId)`。正式 PuzzleDefinition 必须具有唯一精确彩色解，并可纯逻辑完成。颜色不能成为唯一信息，线索、格状态、选择与反馈都必须提供非颜色编码。

正式内容不使用预填格；题目必须仅凭 clues 和标准彩色 Nonogram 规则具有唯一解并可纯逻辑完成。`5×5` 教学、演示和无障碍辅助可以使用预填格；预填属于具体游玩 Session 的辅助层，任何使用预填格的完成均不计为 `completedWithoutHints`。

## Blueprint V1

Blueprint 的事实源必须包含完整彩色网格、稳定 `color IDs`、品牌色号、逐色数量、完成尺寸、底板布局以及 `version/hash`。V1 App 必须提供：

- App 内高清彩色网格。
- PNG 导出。
- 材料清单。
- 系统 Share Sheet。

分页 PDF 是可选 capability，可在 V1 或 V1.1 提供；JPG 只用于预览，不作为生产文件或事实源。详细格式见 [`docs/BEAD_PATTERN_SPEC.md`](docs/BEAD_PATTERN_SPEC.md)。Museum 1 作品清单与制作 brief 见 [`docs/MUSEUM_1_ARTWORK_BRIEFS.md`](docs/MUSEUM_1_ARTWORK_BRIEFS.md)。

## 世界观与英雄画作

正式 canon 为“白蚀”：一种来自外星的语义消除，目标不是烧毁物质，而是抹除图像、记忆与意义之间的连接。画境是真实可进入的有限空间。画桥是长夜前科学家发明的“绘画认知回溯与接驳系统”，当时被误认为神经模拟/历史重构设备；第一代入画者实际进入真实画境后，被白蚀背后的外星力量发现并杀死，现实身体同步死亡，团队、事故记录与技术意义随后遭语义消除。实体机器留在博物馆地下，被误分类为未知旧扫描设备，文明断层后长期无法使用。

第一章六幅修复只恢复一条窄技术知识链：研究员身份 → 接驳锚点 → 地下实验室位置 → 校准/维护记录。章末主角找到机器，A 的程序性身体记忆只让它短启动数秒并产生回声，主角没有完整进入。第二章由当前团队重新校准并重启既有画桥，完成灾后首次、也是主角首次完整进入；这不是当代发明，也不是人类历史上的首次。Museum 1 结尾证明外星力量灾前已主动清除第一代计划，并识别到一个本应被删除的“新操作员”重启了同一座门；B 只表示主角此前未被常规追踪，重启后隐身失效。结尾仍不揭示对方完整外形、社会或最终目标，保持修复而非战斗。画桥原理是否来自对白蚀逆向研究仍开放，但灾前发明、第一代计划与清除事件已经冻结。

Museum 1 英雄画作《潮汐城的归桥》固定为 `3` 个 Repair Fragments，依次对应 `5×5`、`10×10`、`15×15` 彩色谜题。三处修复位于同一次有限 3D 画境 session：用户运行时实时探索预生成、固定边界、有限且确定的空间，每完成一题就恢复对应区域；累计移动、观察与热点交互预算为 `3–5` 分钟，不含 Nonogram 解题、暂停或离开 App 的时间。若移动端性能、可达性或制作质量未达门槛，回退为 `2.5D` 或固定观察点，不改变核心修复与叙事结果。

## 技术路线

- Swift 6.x、SwiftUI；Swift 原生为 V1 主路线。
- SwiftUI `Canvas` + Core Graphics 彩色棋盘。
- SwiftData 本地进度；CloudKit 延至 V1.1。
- StoreKit 2 权益。
- AVFoundation 音频与视频。
- OSLog、MetricKit、Swift Testing / XCTest / XCUITest。
- World Labs 仅用于离线内容生产；禁止在用户运行时生成内容、调用生成 API 或依赖 World Labs 服务。

用户运行时的 3D 仍是实时探索，但所有世界资产均已预生成，并受固定边界、有限交互与确定性状态约束。游戏工程只读取经过验收的图片、彩色答案、世界资产、视频、音频和元数据，不依赖素材生成仓库或生成模型。

## 文档

- [产品对齐决策](docs/ALIGNMENT_DECISIONS.md)
- [故事圣经](docs/STORY.md)
- [游戏设计文档](docs/GAME_DESIGN_DOCUMENT.md)
- [作品资产、章节编排与内容生产规范](docs/CONTENT_CURATION.md)
- [Canon 详设：画境、画桥与文明消除](docs/NARRATIVE_EXPANSION.md)
- [技术决策：Swift 原生与离线画境生产](docs/TECH_EXPLORATION.md)
- [开发与 App Store 发布规划](docs/DEVELOPMENT_PLAN.md)
- [彩色谜题 schema、语义哈希与 solver 规范](docs/PUZZLE_DEFINITION_SPEC.md)
- [拼豆图案事实源规范](docs/BEAD_PATTERN_SPEC.md)
- [Museum 1 作品生产 Brief](docs/MUSEUM_1_ARTWORK_BRIEFS.md)

## 当前状态

项目已进入 M1/M2 技术基线阶段。当前用 Museum 1 冻结规格中的代表性内容验证：

```text
内容导入 → schema、颜色与区域校验 → 唯一精确彩色解验证 → 纯逻辑验证
→ iPhone/iPad 游玩 → Fragment x/n → 最后一块触发整幅恢复
→ Blueprint V1 导出、权限与印章正确派生 → entitlement 不触发 Story milestone
→ 技术知识链与七个独立 Story milestones 顺序验证 → 有限确定性画境验证
```

## 当前可运行开发基线

M0/M1 规则与内容层、M2 进度层、平台无关产品领域闭环，以及 Apple composition 代码已经建立。`Apps/KanakaApp` 包含开发 catalog 驱动的修复室/工坊 reference flow；Apple 条件分支仍需 Xcode 验证。使用 Swift 6.x：

```bash
make build
make validate-fixture
make validate-session
make validate-board-input
make validate-progress
make validate-access
make validate-product
make validate-experience
make validate-app
```

`make validate-fixture` 会递归加载 `Content/Fixtures/`，校验 `Museum → Gallery → Artwork → 1–4 RepairFragments → PuzzleDefinition` 的 schema、ID、归属、引用与归一化区域，并逐题执行 clue、semantic hash、唯一精确彩色解和版本化纯逻辑验证；任一文件失败时返回非零。当前 fixture 覆盖全部 `1 / 2 / 3 / 4` Fragment cardinality。需要查看逐题 deduction steps 时，可运行：

```bash
swift run --package-path Tools/kanaka-content kanaka-content validate-puzzles Content/Fixtures
```

`make validate-session` 使用代表性 `5×5` 题运行纯核心会话闭环：一次批量完成、Undo/Redo、`UInt8` snapshot round trip、恢复时清空内存 history，以及 assistance 不可通过 Undo 恢复无提示资格。

`make validate-board-input` 验证平台无关的大棋盘交互契约：`1×1 / 5×5 / 20×25 / 25×25` 坐标 round trip、top-left 半开边界、焦点缩放、平移 clamp、tap、阈值后行列轴锁、稀疏采样补格、锁定格过滤与第二触点取消。生成的整次拖画只提交一个 `GameSession.applyBatch` transaction；一次 Undo/Redo 覆盖整条 stroke，no-op 与含重复、越界、未知颜色或锁定格的非法 batch 都不能产生部分写入。

`make validate-progress` 验证 `KanakaProgress` 持久化契约：节流自动保存合并、显式 flush 与失败重试状态、assistance-only durability、会话恢复 generation、完成期间重入提交保留、两 Fragment Artwork 的 `1/2 → 2/2` 完成事务，以及旧 generation 写入拒绝。Artwork 查询以 exact-key batch 读取形成一致快照；completion receipt 在最终 snapshot 与 `completedAt` 的同一 Store 操作中返回当前 Fragment 的时间戳集合，ProductDomain 不再二次读取并混合并发状态。内存 Store 可在当前 Linux 基线运行；SwiftData Store 只在 `canImport(SwiftData)` 的 Apple 平台编译，仍需在后续 Xcode / iOS 17（或 macOS 14）环境完成 Apple 分支编译验证。

`make validate-access` 验证 Artwork 的单一访问派生边界：全部当前 Fragment 完成才产生修复状态与印章；匹配的 Museum 蓝图库权益只能授予 Blueprint 使用权，不能修改修复、印章或其他 Museum。受保护的 bead/Blueprint payload 与 export-plan 构造只通过 ProductDomain SPI 提供给 `BlueprintUseService`，普通 App API 必须先经过授权。该 evaluator 不读取或写入 Story、StoreKit、SwiftData，也不决定 legacy revision 政策。

`make validate-product` 运行整体产品闭环：加载并交叉校验 Museum/Gallery/Artwork/Fragment/Puzzle/BeadPattern/Blueprint catalog，以原始 JSON 删除顶层 hash 字段后执行 RFC 8785 JCS + SHA-256（含 ECMAScript number 与 duplicate-member vectors），并拒绝 hash 漂移、越界 RGB、board/grid 不一致、重复材料、多字素辅助符号和低于 8 px/cell 的 Blueprint 导出。`production-assets-v1` manifest 以 `(assetId, revision, hash)` / `(blueprintId, revision, hash)` 显式选择 active revision；CLI 同时装入两代资产并验证升级与回滚都只由 manifest 决定。场景以真实 Fragment ID 打开，变更时自动调度保存，flush 后重启恢复并乱序完成两题；验证原子 `0/2 → 1/2 → 2/2`、完成快照对 live/pre-completion/reopened controllers 均不可变、earned/entitled Blueprint、材料与 PNG 语义导出计划、entitlement 隔离、映射 capability 校验、并发 Story 原子提交，以及 catalog-wide canonical reconciliation 自动收敛。Museum 1 另验证 `28` 个有序 Canon evidence → `7` 个单调 milestones。

`make validate-experience` 校验独立的 `playable-experience-v1` 展示 sidecar：intro、5×5 tutorial、修复室/工坊双入口以及 Museum/Gallery/Artwork/Fragment 本地化必须与事实 catalog 精确覆盖。CLI 同时执行两个 onboarding 分支（完成或跳过教学）、版本化状态 round trip、独立 tutorial `GameSession` 不写入 Progress/Story，以及两 Fragment Artwork 的中间 `1/2` 与最终 `2/2` feedback/Blueprint/seal 边界。展示文案修改不改变 hierarchy、Puzzle、bead 或 Blueprint identity/hash。

`make validate-app` 校验 App Bundle 中的独立单 Artwork/两 Fragment 开发 catalog，运行同一 playable-experience gate，并构建/运行 Linux sentinel。Apple 分支现已实现首次世界观介绍、可跳过且不写作品进度的 `5×5` 教学、修复室/拼豆工坊初始入口、Museum → Gallery → Artwork → Fragment 导航、`5×5 + 1×1` 两阶段修复、单 Canvas 棋盘、一次拖画一个 batch、轴锁、缩放/平移模式、逻辑光标 accessibility actions、mutation autosave、Undo/Redo、阶段化 completion feedback、Workshop 授权、材料/PNG 导出、StoreKit 外部商品映射、SwiftData Story 原子 Store 与 scene-phase session flush。Bundle 内容仍是 synthetic development fixture，不是 Museum 1 正式内容。

当前 Linux gate 只能证明 App 资源契约、依赖方向与 fallback sentinel；它不会编译 `canImport(SwiftUI/SwiftData/StoreKit/CoreGraphics)` 内的实现。真正的 SwiftUI 布局与手势、SwiftData transaction visibility、StoreKit Configuration、PNG 像素结果、Share Sheet、scene suspension、VoiceOver 和真机性能仍必须由 Xcode/iOS 17 或 macOS 14 SDK gate 验证。当前 Swift Package 也仍需由实际签名的 iOS App host target 集成后才能安装到设备。