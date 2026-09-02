# Kanaka 作品资产、章节编排与内容生产规范

> 状态：Draft v1（需通过 Museum 1 垂直切片校准）
> 用途：规定候选画作如何进入 Museum / Gallery / Chapter，如何结合叙事、难度、画境与生产成本排序，以及 `bead-gen` 与本项目的资产边界。
> 权威边界：内容层级、完成规则与权限仍以 `GAME_DESIGN_DOCUMENT.md` 和 `ALIGNMENT_DECISIONS.md` 为准；白蚀、画境、画桥等未冻结设定以 `NARRATIVE_EXPANSION.md` 为探索输入。

## 1. 编排目标

编排不是“先选漂亮的画，再给它补一段文案”，而是让每幅 Artwork 在所在 Chapter 中承担明确工作：

1. 玩家修复前后能看见、听见或理解到清楚的变化；
2. Repair Fragment 对应真实、有语义的破损，而非为了凑题数机械切块；
3. Nonogram 难度符合当前学习阶段，且在整章中形成可持续的节奏；
4. 若使用 3D 画境，探索与恢复反馈服务 Nonogram，不反客为主；
5. 作品来源、权利、人工修整和移动端生产成本可控；
6. 同一 Gallery 的作品共同回答一个叙事问题，又避免题材、色彩、时长与视角连续同质。

核心判断句：

> 如果无法回答“为什么必须在这一章修复这幅画，以及修复后玩家知道了什么”，它就不应进入该 Chapter。

## 2. 内容归属顺序：先 Museum，再 Gallery / Chapter，最后 Fragment

唯一内容树保持不变：

```text
Museum
└─ Gallery（承载 Chapter 叙事映射）
   └─ Artwork
      └─ 1–4 Repair Fragments
         └─ PuzzleDefinition
```

### 2.1 先定 Museum

候选画作必须匹配该 Museum 的：

- 文明主题与时代/媒介范围；
- 玩家当前理解外星文明、白蚀与画境的阶段；
- 内容版本、版权台账和蓝图库权益边界；
- 作品数量、谜题数量、3D 资产与本地化预算。

每幅 Artwork 必须且只能属于一个 Museum。不得用无归属 Chapter 或主题包绕过 Museum 权益边界。

### 2.2 再定 Gallery / Chapter

Gallery 是物理内容容器，Chapter 是它承载的叙事映射。放入某 Gallery 的依据是：

- 作品能承担的叙事岗位；
- 破损物本身表达的意义；
- 当前允许揭示的世界观层级；
- 目标谜题难度带与预计时长；
- 画境模式（无 / 回声 / 2.5D / 有限 3D）；
- 与 Gallery 其他作品形成的节奏和视觉组合。

不要建立独立的 `Chapter → Artwork` 第二棵树；工程归属始终是 `Gallery.artworkIDs`，Chapter 由 `Gallery.chapterNarrativeID` 映射。

### 2.3 最后定 Repair Fragment

作品入选和章节职责明确后，当前项目再定义 1–4 个真实破损：

- 先写“缺失了什么意义”，再画损坏蒙版；
- 先确认画面中确有独立破损，再决定 Fragment 数；
- 再从精确网格区域生成 Nonogram、clues 与 solver 评分；
- 最后决定修复后的 2D、3D、声音、角色记忆和现实档案反馈。

不得先规定“一定要三题”，再为作品制造三个无意义破损。

## 3. 两个项目的资产职责边界

### 3.1 `bead-gen` 负责

`bead-gen` 是 2D 拼豆图资产生产项目，负责：

- 生成完整的彩色拼豆网格；
- 输出版本化、无损的网格 JSON（建议 `bead-pattern-v1`）；
- 输出 PNG/JPG 预览；
- 输出调色板、稳定颜色 ID、品牌色号与色卡版本；
- 记录生成器版本、来源与内容 hash；
- 可附题材、时代、情绪、空间类型等候选标签。

`bead-gen` **不负责**：Museum / Gallery / Chapter 归属、3D 画境、白蚀表现、Repair Fragment 数量与区域、Nonogram 生成、solver 难度、故事与权益。

### 3.2 `painting-nonogram` 负责

当前项目负责：

- 候选资产验收和章节编排；
- 3D 画境生成、人工修整、优化、碰撞、路径与空间音频；
- 破损前后状态和 2D / 3D 对位；
- Repair Fragment 的真实区域与语义；
- Nonogram 答案、clues、唯一解、纯逻辑验证和难度评分；
- Artwork 完成反馈、蓝图、故事事件、内容包、权利与 QA。

### 3.3 无运行时依赖

```text
bead-gen
  → 验收后的 2D 候选资产包
  → painting-nonogram 导入与策展
  → 画境 / Fragment / Puzzle / Blueprint / 内容包
  → App
```

App 不依赖 `bead-gen` 的代码、服务或模型；输入必须是版本化、可 hash、可离线重建的静态资产。

## 4. 明确区分两组“10 个资产”

为消除旧文档中“10 个素材”的歧义，后续统一使用两个代号。

### 4.1 `M1-CANDIDATE-10`：完整候选画作批次

由 `bead-gen` 先产出约 10 幅完整 2D 候选 Artwork 资产，用于 Museum 1 的策展、导入、画境与谜题可行性评估。它们是候选池，不自动成为首发清单，也不改变 Museum 1 的 `12–18` Artworks / `20–30` puzzles 规划包络。

建议覆盖：

| 题材 | 建议数量 | 主要验证 |
|---|---:|---|
| 人物 / 肖像 | 2 | 身份消除、画中居民、局部情感焦点 |
| 城市 / 建筑 | 2 | 可行走空间、道路/桥梁、明确恢复路径 |
| 自然 / 风景 | 2 | 光线、天气、环境声与大尺度变化 |
| 器物 / 工艺 | 2 | 失传技艺、材料与身体记忆 |
| 群像 / 叙事场景 | 2 | 人际关系、复杂焦点与后期揭示 |

批次还应有意覆盖稀疏/高密度轮廓、少色/多色、不同可提取谜题尺寸、平面型/空间型构图和不同权利来源。

### 4.2 `VS-PUZZLE-10`：垂直切片谜题样本

由当前项目从 `M1-CANDIDATE-10` 中选择作品并定义约 10 个 Repair Fragment / PuzzleDefinition 技术样本。推荐装配为四幅测试 Artwork，Fragment 数分别为 `1 / 2 / 3 / 4`，覆盖：

- `1...4` cardinality；
- `x/n` 与每题只恢复一处；
- 最后一块触发整幅恢复；
- Blueprint 与印章派生；
- entitlement 不推进进度；
- 区域、ID、schema、唯一解与存档恢复。

四幅测试 Artwork 仍需满足真实破损原则。如果某画不适合对应数量，应换画或调整测试装配，不得为凑 `1/2/3/4` 破坏作品完整性。

## 5. 每幅作品必须有一个主要“叙事岗位”

一幅 Artwork 只能有一个主要岗位，可有一个次要岗位：

| 岗位 | 作用 | 适合的画 |
|---|---|---|
| `onboarding` | 教一个规则或尽快跑通完整闭环 | 单一焦点、轮廓清楚、1 个低难度 Fragment |
| `reinforce` | 巩固已学规则、给节奏喘息 | 熟悉构图、短局、恢复反馈直接 |
| `question` | 制造异常并提出问题 | 有明显“不该缺席之物”、修复前构图仍能伪装合理 |
| `reveal` | 修复后提供新事实 | 缺失人物/物件能改变历史、关系或档案解释 |
| `turningPoint` | 改变玩家对画境/白蚀/外星文明的理解 | 有可进入空间、可验证的现实因果变化 |
| `climax` | 同时完成 Gallery 的情感与机制高潮 | 恢复层次丰富、焦点强、总时长可承受 |
| `echo` | 回收旧概念或预告下一阶段 | 与早期作品有可辨认的视觉/人物/技法联系 |

仅“画面漂亮”不是叙事岗位。若修复后没有新的认知、感受或行动后果，作品应留在候选池或工坊展示，而非占用 Chapter 节点。

## 6. 候选作品策展卡与准入门

每幅候选画建立一张策展卡。先过硬门，再评分。

### 6.1 候选阶段的一票否决硬门

任一失败即退回候选池，不进入评分：

- 权利、来源或商业使用范围不清；
- 无版本化、无损、可验证的底层网格资产；
- 从画面分析上找不到至少一个真实、有语义、低尺寸仍可能辨认的候选破损区域；
- 作品承担 3D 岗位，但构图无法在预算内转化为稳定路径、热点和移动端空间；
- 与当前 Museum 的主题、权益或发布范围不符。

此阶段只能判断**可行性**，不能宣称谜题已唯一可解或画境已达到性能门。区域、答案、clues 和世界包尚未生产，相关结论必须在后续门禁验证。

### 6.2 Puzzle / World 发布硬门

作品完成 Fragment、谜题和（如适用）画境制作后，任一失败都必须回退到破损设计、章节位置或候选池：

- 谜题不是唯一解或不能纯逻辑完成；
- 目标尺寸下轮廓不可辨认；
- 恢复前后在实际设备上不能清楚区分；
- 3D 世界无法满足性能、舒适度或交互预算；
- 不能提供等价的无障碍路径；
- 最终资产、权利、hash 或人工试玩记录不完整。

无论策展总分多高，发布硬门都不能豁免。

### 6.3 100 分策展评分（初始阈值，垂直切片后校准）

| 维度 | 分值 | 核心问题 |
|---|---:|---|
| 叙事匹配 | 25 | 为什么必须在这一章修？修复后玩家知道什么？ |
| 破损语义 | 15 | 缺失物是否改变画面含义，而非只少一块装饰？ |
| 谜题潜力 | 20 | 轮廓、尺寸、solver 难度与目标玩家阶段是否匹配？ |
| 恢复反馈 | 15 | 2D、画境、声音、人物记忆或档案变化是否清楚？ |
| 画境适配 | 10 | 需要时能否形成有限、可导航、可优化的空间？ |
| 组合价值 | 5 | 是否补足同 Gallery 的题材、色彩、视角和时长？ |
| 权利与生产 | 10 | 授权、人工修整、3D 优化、本地化和 QA 是否可控？ |

候选阈值：

- `< 75`：不入当前 Chapter；保留、返工或转工坊展示；
- `75–84`：可进入标准槽位；
- `85+`：可竞争英雄作品、转折或高潮槽位；
- 无论总分多高，硬门失败都不能发布。

评分不是用精确数字掩盖主观判断。每项必须附一句证据，团队在垂直切片后根据实际完成率、时长、制作成本和叙事理解度校准权重。

### 6.4 `curation-manifest-v1` 字段契约

策展卡不是另一套最终数据；它就是 `curation-manifest-v1.records[]` 中同一条记录随生产状态逐步补全。`candidateAssetID` 是 `bead-gen` 交付物的稳定主键；导入当前项目后建立唯一的 `candidateAssetID → artworkID` 映射。一个候选在同一 Museum 中最多生成一个 Artwork，编译器只放行具有 `artworkID` 且状态为 `approved` 的记录。

| 字段 | 必填阶段 | 规则 |
|---|---|---|
| `candidateAssetID` | 始终 | 对应 bead-gen 交付资产，不因改名或移动目录变化 |
| `artworkID` | `puzzleValidated` 起 | 运行时 Artwork 稳定 ID；与 candidate 一对一 |
| `museumID` | 始终 | 目标 Museum |
| `galleryID` | `provisionallyPlaced` 起 | 最终编译为 Artwork 的 Gallery 归属 |
| `chapterBeatID` | `provisionallyPlaced` 起 | 叙事 beat 引用，不形成第二内容树 |
| `sequenceIndex` | `approved` | 同 Gallery 内唯一的非负整数，编译为 `Gallery.artworkIDs` 顺序 |
| `primaryNarrativeRole` | `provisionallyPlaced` 起 | `onboarding / reinforce / question / reveal / turningPoint / climax / echo` |
| `secondaryNarrativeRole` | 可选 | 与主要岗位相同枚举，但不得相同 |
| `revealLevel` | `provisionallyPlaced` 起 | 本章允许的世界观揭示层级 |
| `tags` | 可选 | `subject / era / mood / spatialType` 等检索标签 |
| `worldMode` | `provisionallyPlaced` 起 | `none / echo / 2.5d / limited3d` |
| `targetArtworkLoadBand` | `provisionallyPlaced` 起 | 整幅负担目标：`short / standard / advanced / expert` |
| `fragmentTargets[]` | `puzzleValidated` 起 | 每项含 `fragmentID`、`targetDifficultyBand`、`solverScore`、`estimatedMinutes`、`damageSemantic` |
| `restorationFeedback` | `provisionallyPlaced` 起 | 2D / 3D / 声音 / 记忆 / 档案反馈摘要 |
| `rightsStatus` | 始终 | `pending / cleared / blocked`；`approved` 必须为 `cleared` |
| `provenance` | 始终 | 来源、生成版本、内容 hash 与权利记录引用 |
| `curationScore` | `provisionallyPlaced` 起 | 当前评分与逐项证据；生产后可重算 |
| `curationStatus` | 始终 | `candidate / provisionallyPlaced / puzzleValidated / worldValidated / approved / returned` |
| `evidenceRefs[]` | `puzzleValidated` 起 | solver、试玩、性能、无障碍和人工审查报告引用 |
| `productionRisks[]` | 始终 | 风险、负责人和回退目标 |

条件规则：

- `worldMode=none|echo`：通过 Puzzle 与通用 QA 后可从 `puzzleValidated` 进入 `approved`；
- `worldMode=2.5d|limited3d`：必须先进入 `worldValidated` 才可 `approved`；
- `approved`：必须拥有 `artworkID`、`galleryID`、`chapterBeatID`、`sequenceIndex`、至少一个 `fragmentTargets`、`rightsStatus=cleared` 和完整 `evidenceRefs`；
- `returned`：必须记录回退到候选、破损、谜题、画境或章节编排中的哪一步，以及原因。

自动测得的 solver、实际时长、内容 hash 和性能数据只能由工具或验收报告写入，不能由策展人手填成“已通过”。

## 7. 难度编排：双轴评估与“上升但不单调”的波形

### 7.1 两个独立轴

- **单题逻辑难度**：棋盘尺寸、solver 推理步骤、线索信息量、连续段、强制格比例、真人实测时长。
- **整幅作品负担**：Fragment 数、各题总时长、画境探索时长、叙事停顿与完成反馈。

Fragment 多不代表单题难，也不自动属于后期。四个简单 Fragment 可以是低逻辑难度但高总时长；一个 20×20 Fragment 可以是高难度但短叙事节点。

### 7.2 章节内难度波形

每个 Gallery 采用“引入 → 巩固 → 小峰值 → 喘息 → 高峰 → 收束”，而非从第一幅到最后一幅机械递增：

```text
短 / 新概念
→ 短 / 巩固
→ 中 / 组合应用
→ 短 / 叙事喘息
→ 中长 / 转折或英雄作品
→ 短中 / 回收与离场
```

规则：

- 新机制或新世界观概念首次出现时，不同时投放本章最高难题；
- 连续两幅 Artwork 不应都是预计 20 分钟以上的高负担内容；
- 高峰后至少提供一幅短局、自由探索或档案回收；
- 多 Fragment Artwork 内部也要有局部波形，不应每题同强度；
- 最后一个 Fragment 尽量落在视觉/叙事焦点，但不伪造破损。

### 7.3 Museum 1 难度带

- Gallery 1：`5×5 / 10×10` 为主，建立规则和信任；
- Gallery 2：`10×10 / 15×15` 为主，增加连续段与组合推理；
- Gallery 3：候选为 `15×15` 为主、少量 `20×20`；最多一题 `25×25`，且必须通过小屏手势与放弃率测试。该建议在 A-006 验证前不视为冻结标准。

Museum 1 整体仍以 30% 短局、45% 标准、20% 高级、5% 专家为目标包络；最终由 solver 与真人测试校准。

## 8. Museum 1：约 10 幅候选画的章节预编排模板

本节把 `NARRATIVE_EXPANSION.md` 的探索方向映射为候选策展模板，**不代表白蚀、画桥或具体揭示顺序已经冻结**。在叙事转正前，团队只承诺与专名无关的功能节奏：Gallery 1 以现实修复/短暂回声为主，Gallery 2 验证一次有限 3D 进入与恢复，Gallery 3 验证更复杂的因果反馈；专名、对白与真相顺序可替换。

以下 `3 / 3 / 4` 只是 `M1-CANDIDATE-10` 的预编排容量，不是首发数量承诺。画作必须过策展卡和硬门；不适合就换画，不为填表强塞。

### 8.1 Gallery 1 / Chapter 1：静默展厅 —— “缺席之物”

**入场认知：** 这是普通的灾后修复工作。
**离场认知：** 某些东西不是损坏，而是被删除；其他人会自动接受恢复后的历史。
**候选数量：** 约 3 幅。
**难度：** 5×5 / 10×10，单焦点、短局优先。
**画境模式：** `none`，结尾最多 `echo`；完整画桥不在本章出现。

适合放入：

- 构图中有一个可被忽略、但恢复后意义立刻改变的人或物；
- 轮廓强、低尺寸仍可辨认；
- 肖像、器物、单一建筑细节等容易建立“这里本来少了什么”的作品；
- 1 个 Fragment 就能跑通整幅完成闭环的教学作品；
- 修复后能触发“它不是一直都在那里吗？”之类记忆矛盾。

不适合放入：

- 必须依赖大范围 3D 探索才能理解的作品；
- 多人物关系复杂、需要大量背景知识的群像；
- 一开始就明确展示外星观察者或文明记忆层真相的作品；
- 高难长题或 3–4 Fragment 高负担作品。

建议岗位顺序：`onboarding → reinforce/question → question + echo`。

### 8.2 Gallery 2 / Chapter 2：烟痕画廊 —— “回声与第一座门”

**入场认知：** 修复区域会产生无法解释的感官回声。
**离场认知：** 画桥可以进入画境；里面的人与空间可能不是模拟。
**候选数量：** 约 3 幅。
**难度：** 10×10 / 15×15。
**画境模式：** 从 `echo` 升级到一幅 `limited3d` 英雄作品。

适合放入：

- 有明确空间纵深、入口、道路、桥梁、室内房间或可导航地标；
- 修复对象能改变路线、声音或画中居民行为；
- 原作允许 3–5 分钟受控探索，不需要开放世界；
- 有 2–3 个彼此独立、语义清楚的破损，可支撑首次完整画境循环；
- 修复后能提供“画中居民记得上次发生的事”等可验证异常。

不适合放入：

- 只能作为静态平面欣赏、强行拉成立体空间会破坏构图的作品；
- 需要高自由度移动、大量 NPC 或复杂物理才能成立的作品；
- 同时承担画桥首秀、最高难题、外星真相和主角身世四个转折的过载作品。

建议岗位顺序：`reinforce/echo → question → turningPoint（英雄作品）`。首次完整进入画境最好在开局一小时内发生。

### 8.3 Gallery 3 / Chapter 3：水下档案 —— “门后有人”

**入场认知：** 画境可能真实存在，修复正在改变更多东西。
**离场认知：** 画境先于画桥存在；白蚀是系统性、有目的的行为，某种存在已注意到人类。
**候选数量：** 约 4 幅。
**难度：** 15×15 为主、少量 20×20；25×25 仅作严格验证候选。
**画境模式：** `2.5d / limited3d`，但仍由 Nonogram 驱动恢复。

适合放入：

- 水痕、烟熏、褪色、倒影、覆盖层等能表现“记录被改写”的作品；
- 群像或叙事场景中，一个缺失者会改变所有人物关系；
- 可让一幅作品的恢复在另一幅作品或现实档案中留下证据；
- 能表现没有回声的空白、停止的水、缺失旋律、重复远景等白蚀现象；
- 最后一幅具有清楚的视觉/情感焦点，但不直接讲完外星文明全部真相。

不适合放入：

- 只靠题目更大、Fragment 更多来假装高潮的作品；
- 修复后只有“颜色更完整”而没有现实/画境后果的作品；
- 需要引入多种全新核心机制才能成立的作品；
- 把 Museum 2 的世界规律（跨作品通道、画桥双向、主角真相等）一次性全部揭晓的作品。

建议岗位顺序：`reveal → reinforce/echo → turningPoint → climax + foreshadow`。

## 9. 新 Chapter 与新 Museum 的概念升级规则

后续内容确实应随玩家深入了解外星文明而出现新概念，但要控制层级：

- **每个 Gallery / Chapter 提出并验证一个新问题**；
- **每个 Museum 最多引入一条主导的新世界规律**；
- 新概念必须改变选画、破损表现或修复反馈，不能只是多一篇日志；
- Nonogram 始终是恢复因果结构的核心，3D 探索与新工具为其提供语境。

每个概念按以下五步呈现：

```text
视觉先兆
→ 玩家操作得到证据
→ 角色给出暂时解释
→ 后续作品产生可验证反转
→ 新认知影响之后的选画与修复
```

探索中的长期阶梯（不是已冻结首发承诺）：

| 范围 | 主导新概念 | 作品编排变化 |
|---|---|---|
| Museum 1 | 白蚀 → 回声 → 画桥 → 画境非模拟 | 从单一缺失物过渡到可进入空间与现实因果证据 |
| Museum 2 | 作品之间彼此连接 | 选择共享人物、地点、技法或意象的作品，形成跨画证据链 |
| Museum 3 | 画桥是双向的 | 选择能表现现实被反向侵入、需要建立“文明锚”的作品 |
| Museum 4 | 底稿、覆画与放弃版本也形成真实分支 | 选择有明确创作层、修改史的作品，支持分层/彩色 Nonogram |
| Museum 5 | 被文明遗忘的人仍存在于作品缝隙 | 用多幅作品保存同一人的手、声音、空间和技法，重建主角身世 |

新 Museum 立项时只冻结最近一馆，后续概念保持可替换，避免远期设定绑死资产生产。

## 10. 端到端编排与生产流程

### Step 1：Museum brief

冻结本馆主题、玩家对外星文明的知识阶段、权益/版权边界、数量包络、目标难度分布、3D 与本地化预算。产物：`Museum Brief`。

### Step 2：Gallery beat sheet

为每个 Gallery 写：入场认知、核心问题、允许揭示、禁止提前揭示、机制带、英雄岗位、高潮与离场认知。产物：`Gallery Beat Sheet`。

### Step 3：建立候选资产池

`bead-gen` 批量产出 `M1-CANDIDATE-10`；记录底层网格、预览、色板、来源和标签。此时不决定 Fragment。产物：`Candidate Asset Inventory`。

### Step 4：候选可行性门与策展卡初评分

先查权利、格式、候选破损轮廓、Museum 适配与初步 3D 可行性，再按 100 分卡给出**暂定**评分、主要叙事岗位和候选 Gallery。此时不得把“唯一解”“实机恢复辨识”或“3D 性能”标为已通过。产物：`Curation Cards (candidate)`。

### Step 5：Gallery 预编排

将候选作品排成章节顺序，检查难度波形、题材/色彩/视角重复、总时长和揭示过载。产物：`Gallery Sequence v0`。

### Step 6：破损设计

当前项目为每幅入围作品定义 1–4 个真实区域。每个区域先写 `damageSemantic`、视觉坐标与网格矩形，再制作损坏蒙版和恢复反馈。产物：`Damage Plan`。

### Step 7：Puzzle 生产、发布门与回退

生成答案、clues，跑唯一解、纯逻辑和难度评分；小尺寸轮廓人工重绘，并在实机验证恢复辨识。通过后更新策展分数和状态；失败时回退破损设计、章节位置或候选池，不能通过“换到别章”掩盖多解/不可辨认问题。产物：`PuzzleDefinition + Solver Report + Curation Card (puzzleValidated)`。

### Step 8：画境生产

只对岗位需要的作品制作画境。当前项目负责离线生成、人工修整、碰撞、路径、热点、破损状态、声音、移动端优化与 Nonogram 对位。先完成一幅英雄作品，再复制生产方法；通过性能、舒适度和无障碍门后将状态更新为 `worldValidated`。产物：`World Package + Performance Report`。

### Step 9：自动与人工验收

自动检查 schema、ID、region、hash、rights、clues、唯一解、solver 和资源尺寸；人工验证时长、触控、叙事理解、恢复辨识、3D 舒适度与无障碍等价路径。状态按 `candidate → provisionallyPlaced → puzzleValidated → worldValidated（若需要）→ approved` 前进；任一门失败进入 `returned` 并注明回退目标。产物：`Content QA Report`。

### Step 10：冻结与变更控制

冻结 `Gallery Sequence` 并写入生产审批用 `curation-manifest-v1`。编译器只接收 `approved` 记录，并把冻结顺序写入运行时 `Gallery.artworkIDs`；该顺序不替代 Story 解锁规则。换 Gallery、改变叙事岗位、增减 Fragment、改变谜题答案或画境模式都必须重新跑相关 validator、权利与叙事审查。产物：`curation-manifest-v1 + Compiled Content Manifest`。

## 11. Gallery 级验收清单

每个 Gallery 冻结前必须回答：

- [ ] 每幅作品都有一个主要叙事岗位，没有纯填充内容；
- [ ] 玩家入场与离场认知发生了可描述变化；
- [ ] 没有提前泄露后续 Museum 的主导概念；
- [ ] 难度上升但不单调，没有连续长题堆叠；
- [ ] Fragment 数来自真实破损，不来自时长指标；
- [ ] 至少有一次清晰的恢复反馈峰值；
- [ ] 题材、文化、人物、色彩和空间视角没有连续同质；
- [ ] 所有谜题唯一、纯逻辑可解，并有真人试玩记录；
- [ ] 所有作品权利、来源、hash 与人工修整记录完整；
- [ ] 3D 画境在目标设备达到性能、舒适度与无障碍门槛；
- [ ] 整章预计时长符合 Museum brief；
- [ ] 蓝图在不推进故事进度的权益路径下仍能独立使用。

## 12. 当前待验证项

- 100 分评分权重和 `75 / 85` 阈值需用首批候选资产校准；
- `M1-CANDIDATE-10` 是否全部进入 Museum 1，还是部分只作技术/工坊候选；
- `VS-PUZZLE-10` 的最终 Artwork 装配和难度分布；
- Gallery 3 的 20×20 / 25×25 比例；
- 每幅画境采用回声、2.5D、固定观察点或有限 3D 的成本上限；
- 白蚀、画桥与后续 Museum 概念在转正前仍属于叙事探索；
- `bead-pattern-v1` 的字段级 schema、hash canonicalization 与版本迁移规则。
