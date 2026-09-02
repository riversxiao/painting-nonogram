# 技术决策附录：Swift 原生与离线画境生产

> 状态：V1 决策已冻结。
> 结论：V1 使用 Swift 原生 App；Godot 不进入 V1 技术栈；World Labs 只作为离线内容生产工具。App 运行时不调用生成 API，可实时探索的画境必须是随内容发布、固定、有限、确定性的 3D 资产。
> 信息核实时间：2026-09。外部链接为一手来源。

## 1. 冻结背景与技术边界

项目当前尚无实现代码，因此在进入工程阶段前冻结以下边界：

- Swift 6 + SwiftUI 承载 App shell、页面与导航。
- 彩色 Nonogram 棋盘使用 SwiftUI `Canvas` + Core Graphics，复杂手势必要时桥接 UIKit。
- SwiftData 负责本地存档，StoreKit 2 负责权益，AVFoundation/Core Haptics 负责音频与触觉。
- 画境运行时使用 Apple 原生 3D 能力（优先 RealityKit/SceneKit，2.5D 可使用 SpriteKit/Core Animation），不嵌入第二套游戏引擎。
- CloudKit 只列入 V1.1，不是 V1 发布依赖。
- World Labs/Marble 可参与离线资产制作，但不成为 App 运行时服务、代码依赖或事实源。

该路线服务于本项目“内容型 iOS 应用 + 定制逻辑棋盘 + 有限画境”的产品形态，并优先保证 StoreKit、分享导出、可靠存档、Apple Pencil/触控与完整 Apple 无障碍路径。

## 2. Godot 决策

### 结论：V1 拒绝采用 Godot

V1 不使用全 Godot，也不在 Swift App 中嵌入 Godot。Godot 的自定义 2D、Shader、Tween 和跨平台能力有价值，但不足以抵消以下成本：

1. StoreKit、Share Sheet、PNG/材料清单导出和系统生命周期需要额外原生桥接。
2. VoiceOver、Voice Control、Switch Control、Full Keyboard Access、Dynamic Type 与 Reduce Motion 的质量风险更高。
3. Swift 主体中嵌入 Godot 会引入两套生命周期、渲染、输入、构建和调试流程。
4. V1 的 3D 是少量固定、有限、确定性画境，不需要大范围自由漫游或跨平台引擎。

棋盘的大量网格可由 Canvas/Core Graphics 高效绘制；修复粒子、扫描、溶解与镜头效果由 Core Animation、SpriteKit 或原生 3D 能力完成。Godot 官方能力资料保留为未来多平台评估参考：[Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)、[Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)、[AccessibilityServer](https://docs.godotengine.org/en/stable/classes/class_accessibilityserver.html)。

### 未来重评条件

Godot 不作为 V1 的备用实现。只有在 V1 之后同时出现明确多平台目标、大范围实时 3D 成为核心玩法、团队具备对应引擎能力且原生无障碍方案可达到同等质量时，才另立决策重新评估；该评估不能反向改变 V1 内容事实源与存档协议。

## 3. World Labs / Marble 决策

### 已核实能力

World Labs 的 Marble 可从文本、图像、视频或粗略 3D 布局生成可探索世界，并导出 Gaussian splats、网格或视频，相关能力见 [Marble: A Multimodal World Model](https://worldlabs.ai/blog/marble-world-model) 与 [World API](https://www.worldlabs.ai/blog/announcing-the-world-api)。官方案例 [Musée du Monde](https://www.worldlabs.ai/labs/showcase/musee-du-monde) 和 [Painted Time](https://www.worldlabs.ai/labs/showcase/painted-time) 证明“从博物馆进入画中空间”可形成有效视觉原型。

### 冻结用法：仅离线生产

```text
bead-pattern-v1 / 原始作品与策展要求
  → Marble 或其他离线工具生成候选画境
  → 美术人工调整与语义对位
  → 导出 Splat / Mesh / 360 / 2.5D 素材
  → 减面、烘焙、碰撞、受控路径与热点
  → 添加固定破损状态、环境声与恢复反馈
  → 版本化、hash、验收并打包进 App
```

App 在运行时：

- 不调用 World API、Marble 或任何生成服务；
- 不等待网络生成，不因模型版本变化而改变关卡；
- 只加载已经审核、固定版本、可重复测试的画境资产；
- 可以实时渲染并允许玩家探索，但活动范围、可达路径、观察点、热点、碰撞和修复结果都是有限且确定的；
- Nonogram 的 semantic grid、修复区域与完成状态不由 3D 生成结果决定。

Marble 的标准导出可能包含约 200 万点 splat，低清约 50 万点，高质量网格约 60 万–100 万三角形；进入 iPhone/iPad 前必须优化。导出规格与授权参考 [Export file specs](https://docs.worldlabs.ai/marble/export/specs) 和 [Exporting from Marble](https://docs.worldlabs.ai/marble/export/gaussian-splat)。坐标转换、商业授权、来源、生成版本、人工修改和内容 hash 都必须进入资产台账。

## 4. Museum 1 英雄画作垂直切片

英雄画作《潮汐城的归桥》固定为正好 `3` 个 Repair Fragments，对应三道 V1 彩色 Nonogram：

1. `5×5`：快速建立彩色 clue 与画境恢复对应关系；
2. `10×10`：组合应用同色分隔与异色相邻规则；
3. `15×15`：完成视觉与叙事焦点。

画境规格：

- 在同一画境 session 中提供累计 `3–5` 分钟的有限 3D 探索预算；只计算移动、观察与热点交互，不含 Nonogram 解题、暂停或离开 App；
- 使用受控路径和/或固定观察点，不制作开放世界；
- 仅设置少量与 Fragment 证据直接相关的交互热点；
- 使用环境声与轻微动态强化“真实画境”，不引入复杂 NPC、物理或战斗；
- 每完成一题，只恢复对应 2D 区域、3D 区域、声音/记忆与档案反馈；
- 第三个 Fragment 完成后才触发整幅恢复、完整 Blueprint 和“亲手修复”印章。

### 性能、舒适度与无障碍门

目标设备必须验证帧率、内存、加载时间、热量、触控舒适度、Reduce Motion，以及 VoiceOver/Switch Control 可完成的等价主路径。若有限 3D 未通过任何性能或无障碍发布门，必须按顺序回退为：

1. 受控 `2.5D` 纵深；
2. 固定观察点 + 热点导航。

回退只降低空间表现，不改变三道彩色谜题、Fragment 语义、完成规则或 Canon 剧情证据。

## 5. 对开发规划的约束

- `DEVELOPMENT_PLAN.md` 的正式技术栈为 Swift 原生；不再保留 V1 引擎待决项。
- World Labs 输出只是可替换的离线中间资产；运行时内容必须可在无网络、无生成服务条件下完整游玩。
- 3D 与 2.5D 都必须服从 Nonogram 核心循环，不能成为独立开放世界。
- V1 内容验收必须记录画境资产版本、hash、来源、权利、性能、舒适度和无障碍证据。
- CloudKit 进度同步留在 V1.1；V1 以可靠本地存档、后台 flush 和内容 revision 迁移为准。

## 参考来源

- Godot：[Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html) · [Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) · [AccessibilityServer](https://docs.godotengine.org/en/stable/classes/class_accessibilityserver.html)
- World Labs：[Marble 世界模型](https://worldlabs.ai/blog/marble-world-model) · [World API](https://www.worldlabs.ai/blog/announcing-the-world-api) · [Musée du Monde](https://www.worldlabs.ai/labs/showcase/musee-du-monde) · [Painted Time](https://www.worldlabs.ai/labs/showcase/painted-time) · [导出规格](https://docs.worldlabs.ai/marble/export/specs) · [导出/授权](https://docs.worldlabs.ai/marble/export/gaussian-splat)

> 说明：外部资料内容经改写以符合授权限制。