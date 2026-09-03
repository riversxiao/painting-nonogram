# Kanaka 作品资产、章节编排与内容生产规范

> 状态：Frozen v2（Museum 1 范围与 Canon 已冻结；评分阈值仍由垂直切片校准）
> 用途：规定正式画作如何进入 Museum / Gallery / Chapter，如何结合叙事、彩色难度、画境与生产成本排序，以及 `bead-gen` 与本项目的资产边界。
> 权威边界：内容层级、完成规则与权限仍以 `GAME_DESIGN_DOCUMENT.md` 和 `ALIGNMENT_DECISIONS.md` 为准；白蚀、真实画境与 A+B 主角以 `STORY.md` 和 `NARRATIVE_EXPANSION.md` 的正式 Canon 为准；本文件冻结下述 Museum 1 画桥证据链及揭示上限。
> **Museum 1 画桥 Canon：** 画桥由灾前科学家团队发明，当时被误认为神经模拟/历史重构设备。第一代入画者实际进入真实画境后遭外星力量杀死，现实身体同步死亡；随后团队身份、第一代计划与技术意义遭语义消除。实体机器仍留在博物馆地下，被后人误作来源不明的旧扫描设备。当代团队只负责重新发现、校准与重启，不是发明者；主角是灾后及其本人首次完整进入画境，但不是人类首位入画者。第一代死亡只通过档案、生命体征、空操作位等非正面证据呈现；修复流程始终非战斗。
> 固定范围：Museum 1 = `18` Artworks / `30` Fragment puzzles，分布 `10×1 + 5×2 + 2×3 + 1×4`；Gallery 为 `6幅/8题`、`6/10`、`6/12`。正式清单见 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md)。

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
- 输出 `bead-pattern-v1` JSON，作为完整 Artwork 网格、palette 与物理规格的上游事实源；
- 使用左上原点、row-major、`0=empty`、非零 palette index；
- 为每个 palette 条目提供稳定 `colorId`、`sRGB8`、品牌色号与色卡版本；
- 输出可由 JSON 重建的 PNG/JPG 派生预览；
- 以 canonical JSON 计算 SHA-256，计算时排除 `contentHash` 字段自身；结果写入 `contentHash`，作为 **bead asset hash**；
- 输出 `contentHash` 及其生成所需的完整字段，并记录生成器版本、来源与权利信息；Blueprint hash 与 puzzle semantic hash 由当前项目分别生成；
- 可附题材、时代、情绪、空间类型等检索标签。

字段级协议与 canonicalization 只在 [`BEAD_PATTERN_SPEC.md`](BEAD_PATTERN_SPEC.md) 定义，本文件不另立冲突格式。`bead-gen` **不负责**：Museum / Gallery / Chapter 归属、3D 画境、白蚀表现、Repair Fragment 数量与区域、彩色 Nonogram semantic grid、puzzle semantic hash、solver 难度、故事与权益。

### 3.2 `painting-nonogram` 负责

当前项目负责：

- 正式资产验收和章节编排；
- 3D 画境离线生成、人工修整、优化、碰撞、路径与空间音频；
- 破损前后状态和 2D / 3D 对位；
- Repair Fragment 的真实区域与语义；
- PuzzleDefinition JSON semantic grid（每格 `empty | colorId`）、`(count,colorIndex)` clues、唯一精确彩色解、纯逻辑验证、puzzle semantic hash 和难度评分；
- Artwork 完成反馈、`blueprint-v1` 规范事实源及其 Blueprint hash、故事事件、内容包、权利与 QA。

solution PNG、缩略图、预览和导出 PNG 均为派生/debug 资源，不得作为谜题答案、迁移、完成判断或 hash 的事实源。

### 3.3 无运行时依赖

```text
bead-gen
  → 验收后的 2D 候选资产包
  → painting-nonogram 导入与策展
  → 画境 / Fragment / Puzzle / Blueprint / 内容包
  → App
```

App 不依赖 `bead-gen` 的代码、服务或模型；输入必须是版本化、可 hash、可离线重建的静态资产。

## 4. Museum 1 固定内容矩阵

Museum 1 发布范围不再使用候选批次或垂直切片样本代号。正式 18 幅作品的标题、ID、叙事岗位、Gallery 顺序和 Fragment 目标统一由 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md) 维护；本文件规定治理、配额和验收。

### 4.1 全馆计数

- `18` Artworks；
- `30` Fragment puzzles；
- Artwork Fragment 分布：`10×1 + 5×2 + 2×3 + 1×4`；
- 每个 Fragment 对应一个 V1 彩色 PuzzleDefinition。

这些是编译和发布硬门，不是估算包络。增删或移动作品必须保持正式清单、manifest、Gallery 计数和全馆分布同时一致。

### 4.2 Gallery 配额

| Gallery / Chapter | Artworks | Fragment puzzles | Cardinality 配额 |
|---|---:|---:|---|
| Gallery 1 / Chapter 1 | 6 | 8 | `4×1 + 2×2` |
| Gallery 2 / Chapter 2 | 6 | 10 | `3×1 + 2×2 + 1×3` |
| Gallery 3 / Chapter 3 | 6 | 12 | `3×1 + 1×2 + 1×3 + 1×4` |
| **合计** | **18** | **30** | **`10×1 + 5×2 + 2×3 + 1×4`** |

### 4.3 英雄画作硬规格

Gallery 2 的 `1×3` 槽位用于英雄画作《潮汐城的归桥》，正好包含 3 个真实 Repair Fragments：

- `5×5` 彩色题：建立颜色 clue 与空间恢复对应；
- `10×10` 彩色题：组合同色分隔与异色相邻；
- `15×15` 彩色题：完成叙事与视觉焦点；
- 同一 session 内累计 `3–5` 分钟移动、观察与热点交互，不含三题解题、暂停或离开 App；使用受控路径和/或观察点、少量热点与环境声；
- 若性能、舒适度或无障碍门失败，回退为 2.5D，再失败则采用固定观察点；Fragment、谜题和剧情证据不变。

其他 3-Fragment 或 4-Fragment 作品仍必须从真实破损出发，不得为满足配额机械切块。配额冲突时应替换正式清单中的作品并重新审批，而不是伪造损坏。

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

- 谜题没有唯一精确彩色解，或不能纯逻辑完成；
- `(count,colorIndex)` clues 不符合“同色段至少隔一空格、异色段可直接相邻”，或与 JSON semantic grid 不一致；
- semantic grid 含 `empty | colorId` 之外的答案值，或 palette 无法映射到稳定 `colorId`；
- 目标尺寸下彩色轮廓或颜色区分不可辨认；
- 恢复前后在实际设备上不能清楚区分；
- 3D 世界无法满足性能、舒适度或交互预算，且 2.5D/固定观察点回退仍不能通过；
- 不能提供等价的无障碍路径；
- `bead-pattern-v1`、canonical hash、三类 semantic hashes、最终资产、权利或人工试玩记录不完整；
- Museum 1 的 18/30、Gallery 6/8・6/10・6/12 或 `10×1 + 5×2 + 2×3 + 1×4` 计数发生漂移。

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
| `fragmentTargets[]` | `puzzleValidated` 起 | 每项含 `fragmentID`、`puzzleRevision`、`puzzleSemanticHash`、`targetDifficultyBand`、`solverScore`、`estimatedMinutes`、`damageSemantic`、预填例外标记 |
| `restorationFeedback` | `provisionallyPlaced` 起 | 2D / 3D / 声音 / 记忆 / 档案反馈摘要 |
| `rightsStatus` | 始终 | `pending / cleared / blocked`；`approved` 必须为 `cleared` |
| `provenance` | 始终 | 来源、生成版本、bead asset hash（`contentHash`）、Blueprint hash、puzzle semantic hash 与权利记录引用 |
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

- **单题逻辑难度**：棋盘尺寸、颜色数量、同色分隔/异色相邻组合、solver 推理步骤、线索信息量、强制格比例、真人实测时长。
- **整幅作品负担**：Fragment 数、各题总时长、画境探索时长、叙事停顿与完成反馈。

Fragment 多不代表单题难，也不自动属于后期。四个简单彩色 Fragment 可以是低逻辑难度但高总时长；一个 20×20 彩色 Fragment 可以是高难度但短叙事节点。

所有 V1 正式题都不使用预填格，并必须在无预填条件下具有唯一、精确的彩色解且可纯逻辑完成。教学、演示与无障碍辅助可例外，例外必须记录预填来源并在 manifest 和试玩证据中标记。

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
- Gallery 3：`15×15` 为主、少量 `20×20`；最多一题 `25×25`，且必须通过小屏手势与放弃率测试。具体比例仍需实机验证，但 V1 彩色规则与 18/30 配额已经冻结。

Museum 1 整体仍以 30% 短局、45% 标准、20% 高级、5% 专家为目标包络；最终由 solver 与真人测试校准。

## 8. Museum 1：18 幅正式作品的章节编排约束

正式作品逐幅清单统一见 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md)。本节冻结每章认知、数量、题量、cardinality、难度与画境职责；策展评分仍用于替换或返工作品，但不能改变总配额。

### 8.1 Gallery 1 / Chapter 1：静默展厅 —— “被删掉的研究链”

**入场认知：** 这是普通的灾后修复工作；地下那台来源不明的机器只是旧扫描设备。
**离场认知：** 六幅修复只恢复一条窄技术知识链：灾前研究员身份 → 接驳锚点 → 博物馆地下实验室位置 → 校准/维护记录。主角据此找到实体机器，并凭身体记忆让它短暂启动、产生接驳回声，但没有完成接驳或进入画境。
**固定数量：** 6 幅 / 8 题；`4×1 + 2×2`。
**难度：** `5×5 / 10×10` 彩色题，单焦点、短局优先。
**画境模式：** `none`，结尾最多 `echo`；本章只允许遗机短启动，不允许完整接驳或进入画境。

适合放入：

- 可由器物、姿势、标记或档案交叉恢复研究员身份与职责；
- 彩色轮廓强、低尺寸仍可辨认，并能承载接驳锚点编码、实验室定位线索或维护步骤；
- 1 个 Fragment 就能跑通整幅完成闭环的教学作品；
- 修复后能让现实记录增加一条窄技术事实，而不是提前解释真实画境、第一代死亡或外星力量；
- 能把程序性身体记忆表现为主角对校准动作“会做但说不出来源”。

不适合放入：

- 必须依赖大范围 3D 探索才能理解的作品；
- 直接证明画境真实、第一代入画者命运或外星文明全貌的作品；
- 把当代团队写成画桥发明者，或把主角写成人类首位入画者的内容；
- 高难长题、3–4 Fragment 高负担作品或任何战斗式修复。

六幅顺序必须形成 `研究员身份 → 接驳锚点 → 实验室位置 → 校准记录 → 维护记录/身体记忆 → 遗机短启动与回声` 的单向窄链；任何单幅都不得跳到完整接驳。

### 8.2 Gallery 2 / Chapter 2：烟痕画廊 —— “重校准与归桥”

**入场认知：** 地下机器不是普通扫描设备；它能短暂响应主角的身体记忆，但现有知识不足以安全接驳。
**离场认知：** 当代团队已完成遗机的重新校准与灾后重启；主角完成灾后首次、也是其本人首次完整进入，并正式证明画境真实。主角不是人类首位入画者，团队也不是画桥发明者。
**固定数量：** 6 幅 / 10 题；`3×1 + 2×2 + 1×3`。
**难度：** `10×10 / 15×15` 为主；英雄作品固定含 `5×5 / 10×10 / 15×15`。
**画境模式：** 从 `echo` 经诊断与校准升级到一幅 `limited3d` 英雄作品。

适合放入：

- 有明确空间纵深、入口、道路、桥梁、室内房间或可导航地标；
- 修复证据可依次支持遗机诊断、时间同步、接驳路径、锚点重校准与连续性/安全验证；
- 进入后使用累计 `3–5` 分钟的受控探索预算（不含 Nonogram 解题、暂停或离开 App），不需要开放世界；
- 英雄画作正好有 3 个彼此独立、语义清楚的破损；
- 修复后能提供“画中居民记得上次发生的事”等可验证异常，并带回第一代计划的初步痕迹，但不在本章讲明清除者。

英雄画作只使用受控路径和/或观察点、少量热点与环境声。若性能、舒适度或无障碍门失败，按 2.5D、固定观察点顺序回退，不改变三道题、灾后重启或完整进入的叙事证据。

不适合放入：

- 只能作为静态平面欣赏、强行拉成立体空间会破坏构图的作品；
- 需要高自由度移动、大量 NPC 或复杂物理才能成立的作品；
- 把本章重启写成画桥的发明或首次有人使用，或让 entitlement、购买、跳章直接触发接驳；
- 同时承担第一代全部死亡真相、主动清除证明、外星全部真相和主角身世后果的过载作品。

六幅顺序必须形成 `诊断 → 时间同步 → 接驳路径 → 锚点重校准 → 连续性/安全验证 → A12 入场事件先重启遗机，再开始灾后首次完整接驳`；`bridgeRebooted` 必须先于任何可探索的完整画境 session，`firstPostCollapseFullEntryCompleted` 只在该 session 完成后成立。

### 8.3 Gallery 3 / Chapter 3：水下档案 —— “被清除的第一代”

**入场认知：** 画境真实存在，主角已通过灾后重启的遗机完整进入；留下的初步痕迹表明这不是人类第一次接驳。
**离场认知：** 证据证明第一代科学家计划曾被主动语义清除；第一代入画者在真实画境遭外星力量杀死，现实身体同步死亡。Museum 1 末，对方识别到一个按清除逻辑本应不存在的“新操作员”。
**固定数量：** 6 幅 / 12 题；`3×1 + 1×2 + 1×3 + 1×4`。
**难度：** `15×15` 为主、少量 `20×20`；`25×25` 只有在正式 briefs 分配且通过小屏与放弃率门时才能使用。
**画境模式：** `2.5d / limited3d`，仍由彩色 Nonogram 驱动非战斗式恢复。

适合放入：

- 可从观测资料、校准知识、姓名/声音、接驳路径、生命体征或空操作位逐步重建第一代计划；
- 水痕、烟熏、褪色、倒影、覆盖层等能表现“记录被改写”的作品；
- 可让一幅作品的恢复在另一幅作品或现实档案中留下交叉证据；
- 用档案、生命体征中止、空操作位等非正面方式表达画境内遇袭与现实身体同步死亡，不出现战斗复演或死亡奇观；
- 最后一幅具有清楚的视觉/情感焦点，并能组合出“主动清除”与“新操作员被识别”两项证据，但不展示外星文明全貌。

不适合放入：

- 只靠题目更大、Fragment 更多来假装高潮的作品；
- 修复后只有“颜色更完整”而没有现实/画境后果的作品；
- 需要引入多种全新核心机制、战斗或正面暴力展示才能成立的作品；
- 展示外星文明最终外形、解释其全部社会，或提前展开画桥双向侵入与主角真相全部后果的作品。

六幅顺序必须形成 `第一代观测痕迹 → 技术知识 → 人员身份/声音 → 接驳与同步死亡档案 → 团队/计划及清除审计证据 → A18 汇总死亡与清除证据，先正式揭示主动清除，再识别新操作员`，并严格停在该 Museum 1 揭示上限。

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

后续长期阶梯中只有 Museum 1 已冻结；Museum 2+ 是未来策展假设，立项时必须另行冻结：

| 范围 | 主导新概念 | 作品编排变化 |
|---|---|---|
| Museum 1 | 窄技术链恢复 → 遗机短启动 → 重校准/灾后重启 → 主角灾后首次完整进入 → 第一代计划主动清除获证 → 新操作员被识别 | 从档案与程序性身体记忆过渡到有限可进入空间，再以非正面证据重建第一代计划 |
| Museum 2 | 作品之间彼此连接 | 选择共享人物、地点、技法或意象的作品，形成跨画证据链 |
| Museum 3 | 画桥是双向的 | 选择能表现现实被反向侵入、需要建立“文明锚”的作品 |
| Museum 4 | 底稿、覆画与放弃版本也形成真实分支 | 选择有明确创作层、修改史的作品，支持分层彩色语义谜题 |
| Museum 5 | 被文明遗忘的人仍存在于作品缝隙 | 用多幅作品保存同一人的手、声音、空间和技法，重建主角身世 |

新 Museum 立项时只冻结最近一馆，后续概念保持可替换，避免远期设定绑死资产生产。画桥的灾前科学家发明、第一代真实接驳与同步死亡、计划遭语义清除、地下遗机身份均已冻结，不得再解释成当代发明或首次有人入画；外星文明最终外形仍是开放剧情细节，但不能改变 Museum 1 的揭示上限。

## 10. 端到端编排与生产流程

### Step 1：Museum brief

冻结本馆主题、玩家对外星文明的知识阶段、权益/版权边界、固定 `18/30` 数量、`6/8・6/10・6/12` Gallery 配额、目标难度分布、3D 与本地化预算。正式 Artwork 身份和职责从 [`MUSEUM_1_ARTWORK_BRIEFS.md`](MUSEUM_1_ARTWORK_BRIEFS.md) 读取。产物：`Museum Brief`。

### Step 2：Gallery beat sheet

为每个 Gallery 写：入场认知、核心问题、允许揭示、禁止提前揭示、机制带、英雄岗位、高潮与离场认知。产物：`Gallery Beat Sheet`。

### Step 3：建立与补充正式资产池

`bead-gen` 按正式 18 幅 briefs 交付 `bead-pattern-v1`；若某作品未过硬门，则从扩展资产池替换，但替换后仍必须回写正式 briefs、保持计数并重新审批。每项记录 JSON、派生预览、palette、稳定 `colorId`、品牌色号/色卡版本、来源、权利和 canonical hash。产物：`Formal Asset Inventory`。

### Step 4：候选可行性门与策展卡初评分

先查权利、格式、候选破损轮廓、Museum 适配与初步 3D 可行性，再按 100 分卡给出**暂定**评分、主要叙事岗位和候选 Gallery。此时不得把“唯一解”“实机恢复辨识”或“3D 性能”标为已通过。产物：`Curation Cards (candidate)`。

### Step 5：Gallery 预编排

将候选作品排成章节顺序，检查难度波形、题材/色彩/视角重复、总时长和揭示过载。产物：`Gallery Sequence v0`。

### Step 6：破损设计

当前项目为每幅入围作品定义 1–4 个真实区域。每个区域先写 `damageSemantic`、视觉坐标与网格矩形，再制作损坏蒙版和恢复反馈。产物：`Damage Plan`。

### Step 7：彩色 Puzzle 生产、发布门与回退

从 PuzzleDefinition JSON semantic grid（`empty | colorId`）生成 `(count,colorIndex)` clues，验证同色段至少隔一空格、异色段可直接相邻，并跑唯一精确彩色解、纯逻辑和难度评分。正式题禁止预填；教学、演示、无障碍辅助例外必须记录来源并明确标记。小尺寸彩色轮廓人工修整，并在实机验证颜色可区分性与恢复辨识。solution PNG 只能由 JSON 派生用于 debug。通过后写入 puzzle revision 与 puzzle semantic hash 并更新策展状态；失败时回退破损设计、章节位置或资产池，不能通过“换到别章”掩盖多解/不可辨认问题。产物：`PuzzleDefinition + Solver Report + Curation Card (puzzleValidated)`。

### Step 8：画境生产

只对岗位需要的作品制作画境。World Labs/Marble 仅可作为离线生产工具；App 运行时不调用 API 或执行生成。当前项目负责离线生成、人工修整、版本/hash、碰撞、受控路径/观察点、少量热点、破损状态、环境声、移动端优化与彩色 Nonogram 对位。先完成《潮汐城的归桥》英雄作品：正好 3 Fragment，使用 `5×5/10×10/15×15` 彩色题；三处修复位于同一有限、固定、确定性 3D session，每完成一题就恢复对应区域；累计 `3–5` 分钟只计算移动、观察与热点交互，不含解题、暂停或离开 App。叙事验收必须以前五幅完成遗机诊断、时间同步、接驳路径、锚点重校准与连续性/安全验证为前置；A12 入场事件先设置 `bridgeRebooted`，成功后才能打开可探索 session，完成三题并离开 session 后才设置 `firstPostCollapseFullEntryCompleted`。两者分别表示灾后遗机重启与主角本人首次完整进入，不能表述成设备被当代发明或人类首次入画。通过性能、舒适度和无障碍门后更新为 `worldValidated`；失败则回退 2.5D，再失败回退固定观察点。产物：`World Package + Performance/Accessibility Report`。

### Step 9：自动与人工验收

自动检查 schema、ID、region、`bead-pattern-v1`、canonical JSON、三类 semantic hashes、rights、彩色 clues、唯一精确解、纯逻辑 solver、资源尺寸及 18/30 固定计数；人工验证时长、触控、叙事理解、颜色可区分性、恢复辨识、3D 舒适度与无障碍等价路径。状态按 `candidate → provisionallyPlaced → puzzleValidated → worldValidated（若需要）→ approved` 前进；任一门失败进入 `returned` 并注明回退目标。产物：`Content QA Report`。

### Step 10：冻结、迁移与变更控制

冻结 `Gallery Sequence` 并写入生产审批用 `curation-manifest-v1`。编译器只接收 `approved` 记录，并把冻结顺序写入运行时 `Gallery.artworkIDs`；该顺序不替代 Story 解锁规则。换 Gallery、改变叙事岗位、增减 Fragment、改变 semantic grid 或画境模式都必须重新跑相关 validator、权利与叙事审查，并保持 18/30 与各 Gallery 配额。

内容更新的安全边界是：只变更元数据或派生预览且 puzzle semantic hash 不变时不影响 puzzle progress；答案变化必须创建新 puzzle revision；不得静默把旧格子状态解释成新答案。具体玩家记录政策仍待最终确认；当前候选是进行中旧局重置并提示、已完成旧 revision 记录 `completedLegacyRevision` 并允许重玩。确认前不得把该候选作为发布硬门。产物：`curation-manifest-v1 + Compiled Content Manifest + Migration Record`。

## 11. Gallery 级验收清单

每个 Gallery 冻结前必须回答：

- [ ] 每幅作品都有一个主要叙事岗位，没有纯填充内容；
- [ ] Gallery 数量/题量分别符合 `6/8`、`6/10`、`6/12`，全馆符合 18/30 与 `10×1 + 5×2 + 2×3 + 1×4`；
- [ ] 玩家入场与离场认知发生了可描述变化：Chapter 1 只恢复窄技术链并以遗机短启动/回声结束，Chapter 2 才完成重校准、灾后重启与主角首次完整进入，Chapter 3/Museum 1 末才证明第一代计划遭主动清除并触发新操作员被识别；
- [ ] 没有提前泄露后续 Museum 的主导概念；
- [ ] 难度上升但不单调，没有连续长题堆叠；
- [ ] Fragment 数来自真实破损，不来自时长指标；
- [ ] 至少有一次清晰的恢复反馈峰值；
- [ ] 题材、文化、人物、色彩和空间视角没有连续同质；
- [ ] 所有谜题有唯一精确彩色解、纯逻辑可解，并有真人试玩记录；
- [ ] `(count,colorIndex)` clues、同色分隔/异色相邻规则与 JSON semantic grid 一致；
- [ ] `bead-pattern-v1` 是 Artwork 网格/palette/物理规格的上游事实源，`blueprint-v1` 是玩家生产资料的规范事实源，PuzzleDefinition JSON 是答案唯一事实源，PNG 全部可派生重建；
- [ ] 所有作品权利、来源、canonical hash、三类 hashes 与人工修整记录完整；
- [ ] 3D 画境在目标设备达到性能、舒适度与无障碍门槛，或已采用通过门禁的 2.5D/固定观察点回退；
- [ ] 整章预计时长符合 Museum brief；
- [ ] Blueprint V1 可提供 App 内高清网格、PNG、材料清单和 Share Sheet，且不依赖 PDF；
- [ ] 蓝图在不推进故事进度的权益路径下仍能独立使用。

## 12. 当前待验证项（不重开已冻结决策）

- 100 分评分权重和 `75 / 85` 阈值需用正式资产与英雄垂直切片校准；
- Gallery 3 在正式 briefs 内的 `20×20 / 25×25` 具体比例仍须通过小屏和放弃率测试，但不得改变 6 幅/12 题配额；
- 非英雄作品分别采用回声、2.5D、固定观察点或有限 3D 的成本上限；
- 玩家进度迁移政策仍待确认；当前候选为“进行中旧局重置并提示、已完成 legacy revision 保留并允许重玩”，但 revision/hash 不匹配时禁止静默复用旧状态；
- 分页 PDF 可进入 V1 或 V1.1，但 Blueprint 事实源和 V1 必选输出不依赖 PDF；
- [`BEAD_PATTERN_SPEC.md`](BEAD_PATTERN_SPEC.md) 负责冻结 `bead-pattern-v1` 字段级 schema 与 canonicalization 细节，本文件只消费该契约；
- 画桥灾前起源、第一代入画者同步死亡、计划遭主动语义清除、地下遗机身份及当代团队/主角并非发明者或人类首位入画者均为冻结 Canon，不列为开放项；外星文明最终外形仍为开放剧情细节。
