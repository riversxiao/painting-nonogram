# Kanaka 游戏设计文档

> 状态：GDD Draft v2
> 平台：iPhone / iPad
> 类型：叙事型 Classic Nonogram + 拼豆蓝图收藏与制作工具

## 1. 产品愿景

Kanaka 将逻辑解谜和拼豆制作连接在同一产品中。玩家既可以通过 Nonogram 亲手恢复作品，也可以把 App 当作经过策展的拼豆图纸工坊。

同一个 App 提供两条平等路径：

- **学徒成长 / 修复室**：学习 Nonogram、推进故事、恢复作品。
- **专业画师 / 拼豆工坊**：浏览已可用蓝图、准备材料并导出制作文件。

首次启动先建立“长夜”和文明修复署的共同故事，再提供一局可明确跳过的 `5×5` 教学。初始选择只改变默认落点和教学顺序；用户可随时切换路径。

## 2. 目标用户

- **解谜玩家**：需要逻辑推理、难度成长、安静体验和明确完成反馈。
- **拼豆制作者**：需要准确色号、数量、尺寸和可打印图纸，不希望被强迫先解大量谜题。
- **收藏与叙事玩家**：需要世界观、作品档案、环境叙事和视觉恢复过程。

三类用户共享同一内容库，入口、节奏与目标不同。

## 3. 内容层级与词汇

唯一内容层级为：

```text
Museum
└─ Gallery
   └─ Artwork
      └─ 1–4 Repair Fragments
         └─ PuzzleDefinition（一个 Nonogram）
```

- **Museum**：专业蓝图库的内容与权益边界，也是持续发布新内容的边界。
- **Gallery**：Museum 内的展厅；承载 Chapter 叙事映射。Museum 1 可让一个 Gallery 对应一个 Chapter。
- **Artwork**：大部分完好的完整作品；拥有修复状态、整幅蓝图和印章。
- **Repair Fragment**：一个真实局部破损区域，一对一对应一个 Nonogram。

每幅 Artwork 必须配置 `1–4` 个 Repair Fragments。第 2–4 个只在实际存在对应破损时配置；配置后的全部 Fragment 都参与完成判断。不能为延长流程机械切割完好区域。

## 4. 单 App 双路径信息架构

```text
启动
→ 共同故事
→ 可完成或明确跳过的 5×5 教学
→ 平等路径选择
→ 共同修复室
   ├─ 修复工作台
   │  └─ Museum → Gallery → Artwork → Repair Fragment → Nonogram
   ├─ 拼豆工坊
   │  └─ Museum 蓝图库 → Artwork 蓝图 → 材料与导出
   ├─ 收藏档案
   └─ 设置 / 无障碍 / 权益管理
```

两条路径复用同一 Artwork 数据：完整图、受损图、Repair Fragments、puzzles、Blueprint、材料清单、档案文字、Museum 归属和权利记录。

## 5. 状态与权限

### 5.1 独立状态

必须分开保存或派生：

- **Puzzle progress**：`notStarted / inProgress / completed / completedWithoutHints`。
- **Fragment progress**：由对应 Puzzle progress 得出。
- **Artwork restoration**：由该 Artwork 的全部 Fragment 是否完成得出。
- **Gallery/Chapter、Museum 与 Story progress**：由叙事事件独立推进。
- **Blueprint access**：由作品完成或 Museum 蓝图库权益得出。
- **Restorer seal**：仅由作品完成得出。

### 5.2 权限公式

```text
require 1 <= artwork.fragments.count <= 4
artworkRestored = artwork.fragments.allSatisfy(isCompleted)
canUseArtworkBlueprint = artworkRestored OR hasMuseumBlueprintEntitlement(artwork.museumID)
hasRestorerSeal = artworkRestored
```

先校验 Fragment count；无 Fragment 或超过四个的 Artwork 不得进入发布内容。

拥有或被授予 Museum 蓝图库权益时：

- 可以使用该 Museum 中 Artwork 的生产文件、色号、数量和导出能力。
- 不完成任何 Repair Fragment。
- 不恢复任何 Artwork。
- 不推进 Gallery/Chapter、Museum 或故事进度。
- 不授予“亲手修复”印章。

## 6. 核心修复循环

1. 选择 Museum 与 Gallery。
2. 选择一幅 Artwork，查看大部分完好的画面和 `1–4` 个真实破损位置。
3. 选择一个 Repair Fragment；进入对应 Nonogram。
4. 根据行列 clues 填色与排除。
5. 完成后把结果融回 Artwork，只修复对应区域。
6. 显示 `x/n 处已修复`；其他破损保持原状。
7. 若仍有未完成 Fragment，返回 Artwork 继续选择。
8. 若刚完成最后一个 Fragment，立即展示整幅恢复作品，授予整幅可制作拼豆蓝图与亲手修复印章。

一个 Fragment 的 Artwork 在完成一题后直接执行第 8 步。单个 Fragment 默认不授予局部可制作蓝图。

## 7. Artwork 与 Repair Fragment 设计

### 7.1 作品原则

- 大部分画面从一开始就完好，破损必须局部、可见、可解释。
- 一幅 Artwork 的 Fragment 数量取决于真实破损数量，而非目标游玩时长。
- 完整展示图、完整制作蓝图和印章均归属于 Artwork。
- 最后一个 Fragment 应尽量是视觉或叙事焦点，但不能篡改真实破损逻辑。

### 7.2 Fragment 选区原则

- 选择有语义、有轮廓且适合 Nonogram 的区域。
- 每个区域有唯一 ID、归一化坐标与边界。
- 区域必须位于 Artwork 范围内；不同区域不得产生进度歧义。
- 小尺寸轮廓必须人工重绘，不能只做缩放。
- 完成前后变化要清晰，并能准确融回原位置。
- 每个 Fragment 必须且只能引用一个 PuzzleDefinition。

### 7.3 奖励边界

Fragment 完成奖励是局部恢复、`x/n` 更新和必要的档案文字。整幅可制作蓝图仅在 Artwork 完整修复或用户拥有对应 Museum 蓝图库权益时可用。钥匙扣、杯垫等局部衍生物若未来加入，必须作为另行定义的内容奖励，不作为默认完成规则。

### 7.4 作品与章节编排

候选画作必须按 `Museum → Gallery（承载 Chapter）→ Artwork → Repair Fragment` 的顺序归属：先确认 Museum 的主题、版权与发布边界，再依据叙事岗位、难度带和画境模式放入 Gallery，最后由当前项目定义 `1–4` 个真实破损区域。不得先定题数再制造破损，也不得建立独立的 `Chapter → Artwork` 内容树。

每幅入章作品必须有一个主要叙事岗位（教学、巩固、提问、揭示、转折、高潮或回声）。候选阶段先通过权利、无损资产、破损可行性与 Museum/3D 适配门再评分；Fragment 生产后还必须通过唯一纯逻辑解、恢复辨识、性能与无障碍发布门。详细评分、Museum 1 的 `3 / 3 / 4` 候选编排模板、难度波形和十步生产流程见 [`CONTENT_CURATION.md`](CONTENT_CURATION.md)。

## 8. 难度体系

| 损毁等级 | 典型尺寸 | 目标时长 | 用途 |
|---|---:|---:|---|
| 表面划痕 | 5×5 | 1–3 分钟 | 教学 |
| 边角破损 | 10×10 | 3–6 分钟 | 短局 |
| 颜料脱落 | 15×15 | 7–15 分钟 | 标准谜题 |
| 烟熏烧蚀 | 20×20 | 15–30 分钟 | 高级谜题 |
| 画布碎裂 | 25×25 | 25–45 分钟 | 专家谜题 |

单题难度由棋盘尺寸、solver 推理步骤、线索信息量、连续段数量、强制填格比例及实测耗时决定。Fragment 数量不等于单题难度；它只描述一幅 Artwork 有几个需要修复的区域。V1 正式谜题必须唯一解并可纯逻辑完成。

## 9. 操作、提示与失败

### 9.1 格子状态与工具

- `Unknown`：未知。
- `Filled`：确认需要修复。
- `Excluded`：确认不填。
- 工具：修复笔、排除、橡皮、Undo/Redo、Hint、Zoom/Pan。

### 9.2 手势

- 单击操作一个格子。
- 连续拖动按首格动作批量处理，并形成一个 Undo transaction。
- 达到阈值后锁定主要行或列，避免斜向误触。
- 两指只缩放和平移，不改变格子。
- iPad 可支持 Apple Pencil，但不作为必需输入。

### 9.3 提示与失败

- 不使用生命值或等待恢复。
- 即时错误提示可关闭。
- Undo/Redo 不限次数。
- 提示层级：指出可推理行列 → 确定一个格 → 解释一步逻辑。
- 提示不作为付费消耗品。
- 禅模式可关闭计时和错误反馈。

## 10. UI 与完成反馈

### 10.1 Museum / Gallery

- Museum 页面说明该馆的内容范围与蓝图库权益状态。
- Gallery 页面同时显示展厅名与 Chapter 叙事标题，避免把二者当成并列实体。
- Museum 1 使用三个 Galleries，分别映射三个 Chapters。

### 10.2 Artwork 页面

- 显示大部分完好的作品和 `1–4` 个破损位置。
- 作品卡显示 `x/n 处已修复`。
- 已完成位置显示修复结果；未完成位置仍显示真实损毁。
- Fragment 入口显示棋盘尺寸、损毁等级和完成状态。

### 10.3 最后一块完成

- 最后一个区域融回后立即移除所有剩余完成态遮罩。
- 镜头展示整幅修复作品。
- 显示整幅蓝图已获得及“亲手修复”印章。
- Reduce Motion 下用淡入或即时替换完成同样信息传达。

## 11. 拼豆工坊

1. 按 Museum 浏览蓝图库。
2. 查看 Artwork 展示预览、尺寸、颜色数、总豆数、底板数量和预计工时。
3. 使用通过修复获得或由 Museum 蓝图库权益授予的蓝图。
4. 查看分页网格、色号、逐色数量和材料清单。
5. 导出 PDF、PNG 或系统 Share Sheet 支持的文件。
6. 回到修复室挑战对应 Artwork，获得亲手修复印章。

所有用户可看低风险展示预览、成品模拟、尺寸与颜色概况。没有使用权时，不可访问可逐格复制的高清网格、完整色号映射、精确数量、无水印生产文件或分页打印文件。

## 12. 奖励

### 单个 Repair Fragment

- 只修复对应区域。
- 进度从 `x/n` 更新为 `(x+1)/n`。
- 可解锁与该区域有关的档案文字。
- 默认不授予局部可制作蓝图。

### 完成 Artwork 最后一个 Repair Fragment

- 立即展示整幅修复作品。
- 授予整幅可制作拼豆蓝图。
- 授予色号、数量、底板布局、完成尺寸和导出文件的使用权。
- 授予“亲手修复”印章。

### 已有 Museum 蓝图库权益

权益可让整幅蓝图提前可用；玩家之后完成修复时仍获得动画、故事记录和印章。权益不模拟任何进度。

## 13. 商业与权益边界

专业蓝图库以 Museum 为稳定的内容与权益边界：

- Museum 1 的蓝图库权益只覆盖 Museum 1 中的 Artworks。
- Museum 2 是新增 Galleries、Artworks、puzzles 与 blueprints 的新范围。
- 不承诺 Museum 1 权益自动覆盖所有未来 Museums。
- 工坊按 Museum 展示“拥有/已授予蓝图库权益”，避免把销售动作写入核心领域模型。
- Museum entitlement 是稳定边界，不代表已经决定每个 Museum 都对应独立付费 SKU。

A-004 继续验证 SKU、定价、免费序章、完整版、蓝图库权益和组合商品的关系。当前文档不冻结这些组合，也不把主题包或全未来内容承诺写入权限公式。

不采用强制广告、体力、提示币、随机蓝图、抽卡或付费自动完成谜题。订阅不作为首发默认方案。

## 14. 首次体验

1. 可跳过的短开场介绍长夜后的 Museum。
2. 档案 AI 说明文明修复署的共同任务。
3. 提供约 60–90 秒、无计时、无失败惩罚的 `5×5` 教学。
4. 完成或明确跳过教学后，平等展示两条路径。
5. 学徒进入修复工作台；专业画师进入 Museum 蓝图库与材料教学。
6. 免费样本和内容范围由 A-004/A-005 验证，不在此预设商品组合。
7. 任一路径引导结束后进入共同修复室，并突出另一入口。

## 15. 页面清单

- 启动与共同故事开场。
- 可完成或明确跳过的 `5×5` 教学。
- 平等路径选择。
- 修复室主空间。
- Museum 选择与 Museum 详情。
- Gallery / Chapter 浏览。
- Artwork 详情与破损位置。
- Nonogram 棋盘。
- Fragment 融回与整幅完成动画。
- 按 Museum 组织的蓝图库。
- Blueprint 详情、材料清单和导出。
- Museum 蓝图库权益页。
- 收藏档案、设置、无障碍、隐私和权益恢复。

## 16. 无障碍

- 非棋盘 UI 支持 Dynamic Type。
- Filled、Excluded、Unknown 不只靠颜色区分。
- 足够对比度和深色界面。
- Reduce Motion 提供等价完成反馈。
- VoiceOver 可完成 Museum、Gallery、Artwork、工坊、权益和导出路径。
- 棋盘提供逐行/逐格导航和自定义操作。
- 支持 Voice Control、Switch Control 和 Full Keyboard Access 的主要路径。

## 17. Museum 1 V1 范围

A-005 与垂直切片验证前，首发规划是包络而非商店承诺：

- `1` 个 Museum。
- `3` 个 Galleries：静默展厅、烟痕画廊、水下档案。
- `12–18` 幅 Artworks。
- `20–30` 个 Repair Fragment puzzles。
- 制作基线：`15` 幅 Artworks / `24` 个 puzzles。
- 基线示例分布：`9×1、4×2、1×3、1×4`。该分布只服务制作估算与测试覆盖，不冻结最终内容清单或商品承诺。
- 难度目标：30% 短局、45% 标准、20% 高级、5% 专家，待 A-006 校准。

首批资产使用两个明确口径，不能混称“10 个素材”：

- **`M1-CANDIDATE-10`**：由 `bead-gen` 先产出的约 `10` 幅完整 2D 候选 Artwork，用于 Museum 1 策展、导入、画境与谜题可行性评估；它们不自动成为首发清单。
- **`VS-PUZZLE-10`**：由当前项目从候选画作中定义的约 `10` 个 Repair Fragment / PuzzleDefinition 技术样本；推荐用四幅测试 Artwork 覆盖 `1 / 2 / 3 / 4` Fragment cardinality。

两组资产都不代表 Museum 1 最终首发规模。详细职责与编排流程见 [`CONTENT_CURATION.md`](CONTENT_CURATION.md)。

## 18. 成功指标

### 产品

- 教学完成率。
- 首幅 Artwork 完成率。
- 第 1、7、30 日留存。
- 修复室与工坊切换比例。
- 通过修复获得蓝图与通过 Museum 权益使用蓝图的比例。
- 蓝图导出率。

### 质量

- 崩溃率和 hang。
- 存档丢失为零容忍事件。
- 多解/无解正式谜题为零。
- 权益授予与恢复成功率。
- `20×20`、`25×25` 的误触和放弃率。
- Fragment count、区域范围和 ID 校验失败的内容不得发布。

## 19. 开放问题

- **A-004**：SKU、定价、免费序章、完整版、Museum 蓝图库权益及组合方式。
- **A-005**：Museum 1 在 `12–18` Artworks、`20–30` puzzles 包络中的最终规模与语言范围。
- **A-006**：solver、损毁等级、提示和生产质量门。
- **A-007**：PDF、PNG、材料清单与工坊 V1 导出范围。
- **A-009**：用 `CONTENT_CURATION.md` 的准入门和评分流程冻结三个 Galleries 的作品顺序与权利台账。
- Museum 2 的叙事主题、上线时间与权益授予方式。
- `25×25` 在小屏 iPhone 上的方向与缩放体验。
- 已拥有 Museum 蓝图库权益的用户继续修复时，哪些非物质反馈最有效。
