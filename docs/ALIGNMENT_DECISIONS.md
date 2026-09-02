# Kanaka 产品对齐决策

> 用途：记录开发前需要共同确认的关键产品决策，避免设计、内容和工程在实现阶段产生不同理解。
> 状态：持续更新。

## 使用规则

- **待讨论**：尚未形成推荐方案。
- **讨论中**：已有方向，但仍有关键问题未确认。
- **已对齐**：可作为后续设计和实现依据。
- **需验证**：已有明确候选，需要通过原型、产能或用户测试确认。
- **已变更**：原决定被新决定替代，并保留原因。

已对齐不代表所有像素级细节被冻结。影响产品身份、内容生产或技术架构的变更，需要回到本文档更新决定与影响范围。

## 决策索引

| 编号 | 对齐点 | 当前状态 | 当前结论 |
|---|---|---|---|
| A-001 | 作品外层展示系统的视觉风格 | 已对齐 | 灾后博物馆修复 × 高级档案系统 × 安静手工作坊 |
| A-002 | 核心用户与双路径优先级 | 已对齐 | 故事先行；学徒成长与专业画师平等且可切换 |
| A-003 | Artwork 奖励与 Museum 蓝图库权益 | 已对齐 | 整幅完成奖励与 Museum entitlement 公式固定 |
| A-004 | 商业模式与商品结构 | 需验证 | Museum 是稳定权益边界，但 SKU、定价和组合未定 |
| A-005 | Museum 1 V1 内容范围 | 已对齐 | 固定 18 Artworks / 30 puzzles，Fragment 分布与 Gallery 配额冻结 |
| A-006 | 彩色谜题规则与难度标准 | 已对齐 | clue、格状态、唯一精确彩色解与纯逻辑发布门固定 |
| A-007 | Blueprint V1 交付格式 | 已对齐 | 事实源与 App 内高清网格、PNG、材料清单、Share Sheet 固定 |
| A-008 | Artwork 与 Repair Fragment 规则 | 已对齐 | 每幅 Artwork 有 1–4 个真实破损，全部配置项均必修 |
| A-009 | Gallery、作品素材与版权边界 | 需验证 | 编排与配额已冻结；权利台账及 Marble 授权仍需验证 |
| A-010 | 首发市场、本地化与年龄定位 | 待讨论 | 决定文案、字体、商店素材与合规 |
| A-011 | 技术范围与发布质量门 | 已对齐 | Swift 原生主路线、离线世界生产、确定性有限 3D；CloudKit V1.1 |
| A-012 | 世界观与 Museum 1 叙事边界 | 已对齐 | 白蚀、真实画境、A+B 主角、第二章画桥与揭示上限固定 |

---

## A-001：作品外层展示系统的视觉风格

- **状态：已对齐**
- **日期：2026-09-01**
- **影响范围：品牌、UI、场景、美术、动画、音频、无障碍、App Store 素材**

### 决策

Kanaka 不采用完整像素复古风作为 App 外层展示系统。整体风格为：

> **灾后博物馆修复 × 高级档案系统 × 安静手工作坊**

- **场景层**：半写实、安静的博物馆修复室。
- **UI 层**：现代档案与编辑设计，清晰、可信、克制。
- **玩法层**：精确、安静的 Nonogram 网格。
- **奖励层**：彩色整幅拼豆蓝图和制作资料。

核心原则：**像素是被修复的内容，不是操作系统本身。**

### 统一与差异

修复室和拼豆工坊属于同一个 App、同一座档案馆和同一视觉系统，共享字体、图标、卡片、状态、声音和转场语言。修复室可更暗、更有空间感；工坊可更明亮、精确。差异来自工作性质，不是两个模式皮肤。

像素元素用于彩色 Nonogram、拼豆蓝图、扫描网格、Repair Fragment 进度和完成动画，不用于主字体、全局按钮、设置或权益页面。棋盘必须保持最高对比度，并让 `unknown / excluded / filled(colorId)`、clue 与颜色工具都具有非颜色编码。Reduce Motion 下提供淡入或即时结果。

### 原型验证

用修复室主界面、Nonogram 棋盘、拼豆工坊 Blueprint 详情三个高保真屏幕验证视觉统一、可读性、专业感、完成连续性和无障碍。

---

## A-002：故事先行，双路径平等

- **状态：已对齐**
- **日期：2026-09-01**
- **影响范围：开场、首次体验、首页、角色文案、教程和权益展示**

### 决策

首次体验顺序固定为：

1. 建立“长夜”、文明修复署和保存图像的故事背景。
2. 进入无失败压力的 `5×5` 共同教学。
3. 用户可明确跳过；完成或跳过后才开放工坊和路径选择。
4. 平等展示“学徒成长”和“专业画师”。
5. 选择只决定首次落点与引导，不形成永久职业或功能锁定。
6. 进入共同修复室后随时切换。

两条路径共享 Museum、Gallery、Artwork、Blueprint、进度与权益。学徒通过修复成长并获得蓝图；专业画师从蓝图、材料与导出开始，也可进入修复。专业身份不代表拥有全部内容，也不代表跳过进度。

App Store 第一张截图先展示受损作品、清晰棋盘和局部恢复结果，后续平等展示故事、两条路径和工坊价值。截图顺序不改变 App 内路径层级。

### 仍需原型验证

- 路径名称与切换入口。
- `5×5` 教学能否在 60–90 秒内讲清 `unknown / excluded / filled(colorId)`、彩色线索与同色/异色段间距规则。
- 工坊教学所需的免费样本范围；该范围由 A-004 决定。

---

## A-003：Artwork 奖励与 Museum 蓝图库权益

- **状态：已对齐**
- **日期：2026-09-01**
- **影响范围：完成反馈、Blueprint 使用权、印章、entitlement resolver、持续内容边界**

### 决策

完成每个 Repair Fragment 时，只修复对应区域并更新 `x/n`。完成该 Artwork 的最后一个 Fragment 后，必须立即：

1. 展示整幅修复作品。
2. 授予整幅可制作拼豆蓝图。
3. 授予“亲手修复”印章。

默认不授予局部可制作蓝图。局部衍生物若未来加入，应作为另行定义的内容奖励，不能成为默认完成规则。

### 权限公式

```text
require 1 <= artwork.fragments.count <= 4
artworkRestored = artwork.fragments.allSatisfy(isCompleted)
canUseArtworkBlueprint = artworkRestored OR hasMuseumBlueprintEntitlement(artwork.museumID)
hasRestorerSeal = artworkRestored
```

count 校验必须先执行。`artworkRestored`、`canUseArtworkBlueprint` 和 `hasRestorerSeal` 均为派生状态，不得各自形成可冲突的持久化真相。

### Museum entitlement 的作用边界

拥有或被授予某 Museum 的蓝图库权益，只让该 Museum 的 Blueprint 生产文件可用。它不会：

- 完成 Repair Fragment。
- 恢复 Artwork。
- 推进 Gallery/Chapter。
- 推进 Museum。
- 推进故事。
- 授予亲手修复印章。

用户以后仍可正常修复；亲手完成时获得动画、叙事记录和印章。

### 持续内容边界

专业蓝图库以 Museum 为内容与权益边界：

```text
Museum 1 entitlement → Museum 1 Blueprints
Museum 2 entitlement → Museum 2 Blueprints
```

Museum 2 是新增 Galleries、Artworks、puzzles 与 blueprints 的新范围。不得承诺 Museum 1 entitlement 自动覆盖所有未来 Museums。Museum 是稳定边界，但不表示已决定每馆都对应独立付费 SKU；授予来源和商品组合由 A-004 验证。

---

## A-004：商业模式与商品结构

- **状态：需验证**
- **日期：2026-09-01**
- **影响范围：StoreKit、免费边界、权益页、升级与商店文案**

### 已确定边界

- 领域层只识别“拥有/已授予 Museum 蓝图库权益”。
- Museum entitlement 与 Repair Fragment、Artwork、Gallery/Chapter、Museum 和故事进度正交。
- Museum 1 entitlement 不自动覆盖 Museum 2。
- 一个 SKU 可授予一个或多个 entitlements；一个 entitlement 也可由不同来源授予。

### 待验证

- 免费序章、完整版和专业蓝图库权益如何组合。
- 是否存在单独 SKU、组合 SKU 或升级路径。
- 定价、地区策略、恢复权益和免费 Blueprint 样本。
- 主题展示是否只是商店分组，还是需要额外 entitlement；不得破坏 Museum 边界。

在验证完成前，文档不得把任一组合写成已承诺商业方案。

---

## A-005：Museum 1 V1 内容范围

- **状态：已对齐**
- **日期：2026-09-01**
- **影响范围：周期、预算、内容生产、本地化、QA 与商店范围**

### 决策

Museum 1 V1 固定为：

- `3` 个 Galleries。
- `18` 幅 Artworks。
- `30` 个 Repair Fragment puzzles。

Fragment cardinality 的精确分布为：

```text
10 幅 Artwork × 1 Fragment = 10 puzzles
5 幅 Artwork × 2 Fragments = 10 puzzles
2 幅 Artwork × 3 Fragments = 6 puzzles
1 幅 Artwork × 4 Fragments = 4 puzzles
合计：18 Artworks / 30 puzzles
```

Gallery 的精确内容分配为：

```text
静默展厅：6 Artworks / 8 puzzles
烟痕画廊：6 Artworks / 10 puzzles
水下档案：6 Artworks / 12 puzzles
合计：18 Artworks / 30 puzzles
```

三个 Galleries 各自承载一个 Chapter，并在 Museum 1 中使用 1:1 叙事映射。作品清单、Fragment 归属、难度波形和制作 brief 由 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md) 固化；不得再使用候选样本集或范围包络代替发布目标。

数量已经冻结。仍可通过垂直切片校准单题时长、颜色数量、制作成本和 Gallery 内顺序，但不得以此改变 `18 / 30` 总量、`10×1 + 5×2 + 2×3 + 1×4` 分布或 `6/8、6/10、6/12` 配额；如需改变，必须建立新的显式产品决策。

---

## A-006：彩色谜题规则与难度标准

- **状态：已对齐**
- **日期：2026-09-02**
- **影响范围：PuzzleDefinition、solver、validator、棋盘、教学、提示、内容生产与无障碍**

### 决策

V1 正式玩法为彩色 Nonogram：

```text
clue = (count, colorIndex)
cellState = unknown | excluded | filled(colorId)
```

- 同色连续段之间至少有一个空格。
- 异色连续段可以直接相邻。
- `colorIndex` 必须稳定映射到 PuzzleDefinition 使用的 `colorId`，不得依赖显示顺序猜测颜色身份。
- 正式谜题必须有且只有一个精确彩色解，并可在不猜测的情况下纯逻辑完成。
- solver 与 validator 必须按颜色、段间距和相邻规则验证完整解，不能只验证是否填格的外轮廓。

颜色不可作为唯一信息。行列线索、格状态、当前工具、选择、正确/错误反馈和完成状态必须同时使用文本、符号、形状、纹理、边框或无障碍标签中的适当组合。色觉差异或灰阶显示不能让玩家失去解题所需信息。

### 预填格边界

正式内容无预填格目前是**推荐方案，待用户最终确认**，因此不能写成已冻结的发布门。`5×5` 教学、演示和无障碍模式可以使用预填格；任何使用预填格的完成都不计入 `completedWithoutHints`。最终确认前，schema 应能明确表达预填来源，并让统计与奖励逻辑区分纯玩家完成和辅助完成。

### 难度质量门

棋盘尺寸、颜色数量、连续段数量、强制格比例、solver 推理步骤与玩家实测共同决定难度。Fragment 数量只表示真实破损数量，不表示单题难度。正式内容必须通过唯一精确彩色解、纯逻辑可解、线索可辨认、无颜色单点依赖和目标设备可操作性验证。

---

## A-007：Blueprint V1 交付格式

- **状态：已对齐**
- **日期：2026-09-02**
- **影响范围：内容 schema、工坊、导出、版本管理、材料清单与 QA**

### 事实源

Blueprint 的规范事实源必须包含：

- 完整彩色网格。
- 稳定 `color IDs`。
- 品牌色号映射。
- 逐色数量与总数量。
- 完成尺寸。
- 底板布局。
- `version/hash`。

字段定义、验证规则和文件结构以 [`BEAD_PATTERN_SPEC.md`](BEAD_PATTERN_SPEC.md) 为准。JPG 不能作为事实源。

### V1 必需能力

- App 内高清彩色网格。
- PNG 导出。
- 材料清单。
- 系统 Share Sheet。

分页 PDF 是可选 capability，可根据实现与 QA 结果进入 V1 或 V1.1，不构成 V1 发布阻塞。JPG 只允许用于低风险展示预览，不作为生产文件、逐格复制文件或长期版本依据。

Blueprint 的使用权继续由 A-003 的 Artwork 完成或 Museum entitlement 公式派生；交付格式不改变修复进度、印章或叙事状态。

---

## A-008：Artwork 与 Repair Fragment 规则

- **状态：已对齐**
- **日期：2026-09-01**
- **影响范围：内容层级、选区、美术生产、schema、validator、UI 和完成判断**

### 唯一内容层级

```text
Museum
└─ Gallery（承载 Chapter 叙事映射；Museum 1 可 1:1）
   └─ Artwork
      └─ 1–4 Repair Fragments
         └─ 一个真实破损区域 + 一个 Nonogram
```

Chapter 不是 Gallery 的父级或同级内容容器。它是 Gallery 承载的叙事映射；工程目录和 schema 使用 Museum/Gallery/Artwork/RepairFragment。

### 数量与完成规则

- 每幅 Artwork 大部分保持完好。
- 每幅 Artwork 必须存在 `1–4` 个真实局部破损区域。
- 每个 Repair Fragment 一对一对应其中一个区域和一个 Nonogram。
- 第 2–4 个仅在作品确有对应破损时配置。
- 一旦配置，全部 Repair Fragments 都参与 `artworkRestored` 判断。
- 一个 Fragment 的 Artwork 完成一题就立即触发整幅完成反馈。
- 不按优先级拆分完成集合，也不设第二套收藏完成度。

### 选区与 validator

- Fragment 区域必须有意义、可辨认、适合 Nonogram，不能机械等分完好画面。
- 区域使用归一化坐标且完整位于 Artwork 边界内。
- Museum、Gallery、Artwork、RepairFragment、PuzzleDefinition 与 Blueprint ID 必须唯一且引用有效。
- validator 必须拒绝 count 不在 `1...4`、区域越界、空区域、悬空引用、重复 ID 或任何未进入完成集合的配置 Fragment。

### 难度边界

Fragment 数量表示需要修复几个真实区域，不等于单题难度。单题难度由棋盘尺寸、颜色数量、彩色线索结构、solver 推理步骤和玩家实测决定，并遵循 A-006 的唯一精确彩色解与纯逻辑发布门。

### 变更原因

早期方案把一幅作品拆成不同优先级的局部集合，造成奖励、UI、存档和内容生产出现两套完成口径。现统一为“配置即必修”：内容设计只决定真实破损有几个，系统完成条件始终是全部配置项完成。

---

## A-009：Gallery 编排、作品资产与版权边界

- **状态：需验证**
- **日期：2026-09-02**
- **影响范围：bead-gen 交接、Museum/Gallery/Chapter 编排、谜题、3D 画境、权利台账、内容 QA**

### 已冻结的编排边界

详细流程以 [`CONTENT_CURATION.md`](CONTENT_CURATION.md) 为主规范，Museum 1 作品级 brief 以 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md) 为准：

1. 先按主题、世界观阶段、权益与版权边界确认 Museum；
2. 再按叙事岗位、难度带、画境模式和组合节奏把 Artwork 放入 Gallery（Chapter 只通过 `chapterNarrativeID` 映射）；
3. 最后为每幅 Artwork 定义 1–4 个真实破损、彩色 Nonogram 与恢复反馈。

Museum 1 固定为三个 Gallery 各 `6` 幅 Artwork，谜题配额依次为 `8 / 10 / 12`。每幅入章作品必须有一个主要叙事岗位。Fragment、谜题与世界包生产后，必须通过唯一精确彩色解、纯逻辑可解、恢复辨识、性能、无颜色单点依赖与无障碍发布门，任何策展评分都不能豁免这些门槛。

### 资产与项目职责

- `bead-gen` 只交付完整 2D 拼豆网格、预览、调色板、来源与 hash。
- 当前项目负责章节编排、有限 3D 画境、破损、彩色 Nonogram、solver、恢复反馈、内容包和 QA。
- App 不在运行时依赖 `bead-gen`、World Labs 或任何生成服务。
- Blueprint 事实源必须符合 A-007 与 [`BEAD_PATTERN_SPEC.md`](BEAD_PATTERN_SPEC.md)。

### 英雄画作固定规格

Museum 1 英雄画作《潮汐城的归桥》固定为 `3` 个 Repair Fragments，分别对应 `5×5`、`10×10`、`15×15` 彩色谜题。三处修复位于同一次预生成、固定边界、有限且确定的实时 3D 画境 session，每完成一题就恢复对应区域；`3–5` 分钟只计算移动、观察和热点交互，不含 Nonogram 解题、暂停或离开 App。若性能、无障碍或生产质量未达到发布门，回退为 `2.5D` 或固定观察点；核心谜题、恢复结果与叙事揭示保持不变。

### 仍需验证

A-009 继续保持“需验证”，原因不是数量或编排未定，而是：

- 18 幅作品的来源、权利与版本台账尚未全部闭合。
- Marble 相关素材或能力的授权范围尚未最终确认。
- 英雄画作的有限 3D 包仍需通过移动端性能、可达性与质量验收。
- 作品级颜色、Fragment 轮廓和 Gallery 内顺序仍需制作验证，但不得改变 A-005 的冻结总量与配额。

---

## A-011：技术范围与发布质量门

- **状态：已对齐**
- **日期：2026-09-02**
- **影响范围：客户端架构、内容生产、3D 运行时、同步、性能、隐私与发布 QA**

### 决策

- V1 以 Swift 6.x、SwiftUI、SwiftData、StoreKit 2 和 Apple 原生框架为主路线。
- 彩色棋盘采用 SwiftUI `Canvas` + Core Graphics；性能与无障碍质量门必须覆盖目标 iPhone 与 iPad。
- World Labs 仅用于离线生产世界资产，不进入用户运行时依赖。
- 禁止用户运行时生成世界、调用 World Labs 或其他生成 API，禁止把网络生成成功作为玩法、恢复或叙事前提。
- 用户运行时仍实时探索已经预生成的 3D 内容；空间具有固定边界、有限交互和确定性状态，同一版本与输入必须得到可复现结果。
- CloudKit 不进入 V1，计划在 V1.1 提供；V1 使用 SwiftData 保存本地进度，并把迁移、备份边界和存档丢失零容忍作为发布质量门。

World Labs 的离线使用不能改变当前项目对资产验收、来源记录、hash、版本、设备性能和回退方案的责任。英雄画境遵循 A-009 的固定有限 3D 规则；`3–5` 分钟仅指累计探索预算，不含三道 Nonogram 的解题时间。

---

## A-012：世界观与 Museum 1 叙事边界

- **状态：已对齐**
- **日期：2026-09-02**
- **影响范围：故事圣经、Gallery/Chapter 编排、角色、画境、英雄画作、档案文案与后续 Museum**

### 正式 canon

- 长夜背后的威胁称为“白蚀”，本质是外星力量实施的语义消除：它抹除图像、记忆、名称与意义之间的连接，而不只是破坏物质表面。
- 画境是真实存在、可以进入的空间，不是纯幻觉、视频或比喻。
- 主角采用 A+B 组合设定：画师的程序性身体记忆，与童年曾被白蚀从身份记录中删除的经历共同成立。
- 画桥在第二章出现，承担现实修复与画境之间的稳定连接。
- Museum 1 的揭示上限固定为：证明消除具有目的性，并证明对方已经注意到人类。

Museum 1 不解释对方的完整身份、最终目标、文明全貌或冲突结局；这些答案保留给后续 Museum。环境文本、英雄画作和结尾不得越过该揭示上限，也不得把白蚀重新解释为普通自然灾害、单纯数据损坏或纯心理现象。

### 英雄画作叙事职责

英雄画作以 `3` 个逐级扩展的彩色谜题和累计 `3–5` 分钟探索预算的有限画境证明“修复的不是静态图像，而是可被重新连接的真实意义空间”；探索预算不含解题、暂停或离开 App。3D 回退只改变呈现方式，不改变画境为真实空间的 canon，也不改变 Museum 1 的揭示结论。

---

## 后续对齐顺序

1. A-009：闭合 18 幅作品权利台账、Marble 授权和英雄画境发布验收。
2. A-004：用冻结内容与 Blueprint V1 测试 Museum entitlement 的商品表达。
3. A-010：冻结首发市场、本地化语言、年龄定位与商店合规。
4. 正式确认 A-006 中“正式内容无预填格”的推荐方案。
5. 玩家进度迁移政策：确认 revision 变化后进行中局与已完成记录的具体处理；当前只有“禁止静默重解释旧状态”是硬边界。
6. 在 V1 数据与质量门稳定后，规划 CloudKit V1.1 与可选分页 PDF。
