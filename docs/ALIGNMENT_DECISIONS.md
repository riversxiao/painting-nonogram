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
| A-005 | Museum 1 V1 内容范围 | 需验证 | 先使用首发包络与制作基线，垂直切片后冻结 |
| A-006 | 谜题规则与难度标准 | 待讨论 | 决定 solver、教学、提示和生产质量门 |
| A-007 | 蓝图交付格式 | 待讨论 | 决定 PDF/PNG/材料清单与工坊能力 |
| A-008 | Artwork 与 Repair Fragment 规则 | 已对齐 | 每幅 Artwork 有 1–4 个真实破损，全部配置项均必修 |
| A-009 | Gallery、作品素材与版权边界 | 待讨论 | 决定可发布内容与权利台账 |
| A-010 | 首发市场、本地化与年龄定位 | 待讨论 | 决定文案、字体、商店素材与合规 |
| A-011 | 技术范围与发布质量门 | 待讨论 | 决定最低系统、同步、分析、性能和测试范围 |

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

像素元素用于 Nonogram、拼豆蓝图、扫描网格、Repair Fragment 进度和完成动画，不用于主字体、全局按钮、设置或权益页面。棋盘必须保持最高对比度，并让 Filled、Excluded、Unknown 不只依赖颜色区分。Reduce Motion 下提供淡入或即时结果。

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
- `5×5` 教学能否在 60–90 秒内讲清 Filled、Excluded 与线索。
- 工坊教学所需的免费样本范围；该范围由 A-004/A-005 决定。

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

- **状态：需验证**
- **日期：2026-09-01**
- **影响范围：周期、预算、内容生产、本地化、QA 与商店范围**

### 首发规划包络

在垂直切片验证产能、难度与留存前，Museum 1 使用：

- `3` 个 Galleries。
- `12–18` 幅 Artworks。
- `20–30` 个 Repair Fragment puzzles。

制作基线为 `15` 幅 Artworks / `24` 个 puzzles。用于排期的示例分布是：

```text
9 幅 Artwork × 1 Fragment = 9 puzzles
4 幅 Artwork × 2 Fragments = 8 puzzles
1 幅 Artwork × 3 Fragments = 3 puzzles
1 幅 Artwork × 4 Fragments = 4 puzzles
合计：15 Artworks / 24 puzzles
```

该分布只用于内容生产估算、schema 覆盖和排期，不是最终内容清单或商店承诺。最终数量必须在 A-005 验证后冻结。

现有 `10` 个素材仅用于技术验证。合理的垂直切片组织方式是四幅 Artwork，Fragment 数量分别为 1、2、3、4，从而覆盖全部 cardinality 和最后一题完成边界；这些素材不代表首发规模。

### Museum 1 叙事范围

三个 Galleries 为静默展厅、烟痕画廊、水下档案，并各自承载一个 Chapter；结尾使用短尾声。“迁徙的收藏”和“失落名作”移至 Museum 2 或未来概念，不计入 Museum 1 承诺。

### 验证项目

- 单幅完成时长与 Museum 总时长。
- 1–4 Fragment 分布是否自然。
- `20–30` puzzles 的内容产能与 QA 成本。
- 本地化语言与美术权利预算。
- 免费内容范围与 A-004 商品结构的关系。

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

Fragment 数量表示需要修复几个真实区域，不等于单题难度。单题难度由棋盘尺寸、线索、solver 推理步骤和玩家实测决定。

### 变更原因

早期方案把一幅作品拆成不同优先级的局部集合，造成奖励、UI、存档和内容生产出现两套完成口径。现统一为“配置即必修”：内容设计只决定真实破损有几个，系统完成条件始终是全部配置项完成。

---

## 后续对齐顺序

1. A-006：谜题规则、solver、提示与难度质量门。
2. A-007：整幅 Blueprint 的 V1 交付格式。
3. A-004：用垂直切片测试 Museum entitlement 的商品表达。
4. A-005：根据制作数据冻结 Museum 1 最终范围。
5. A-009：锁定三个 Galleries 的素材与权利台账。
