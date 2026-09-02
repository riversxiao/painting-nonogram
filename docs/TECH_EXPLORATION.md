# 技术探索：Godot 与 World Labs（画境实现）

> 状态：探索中（Exploration）。本文件记录围绕引擎选型与画境实现的技术讨论，供团队评审。
> 结论应在正式采纳后回写进 `DEVELOPMENT_PLAN.md`（技术栈）与 `ALIGNMENT_DECISIONS.md`（A-011 技术范围）。
> 信息核实时间：2026-09。外部链接为一手来源。

## 1. 背景与当前状态

- 项目当前只有文档，尚无实现代码（无 Swift 工程、无 `project.godot`、无内容 JSON/资源）。因此**现在是切换或确认技术路线成本最低的时点**。
- `DEVELOPMENT_PLAN.md` 已围绕 Apple 原生能力做了详细规划：Swift 6 + SwiftUI、棋盘用 Canvas/Core Graphics、SwiftData 存档、StoreKit 2 权益、AVFoundation 音视频、完整 Apple 无障碍、MetricKit/TestFlight/XCUITest，以及一个 macOS Swift 内容 CLI。
- `ALIGNMENT_DECISIONS.md` 中 **A-011（技术范围）仍标为待讨论**，`README.md` 也称 Swift 栈为“推荐技术栈”，因此 Godot 并未被正式排除，只是尚未评估。

## 2. Godot 评估

### 结论

**Godot 对项目有帮助，但现阶段不建议把整个项目切到 Godot。**

- SwiftUI + Canvas/Core Graphics：项目适配度约 **9/10**
- 全 Godot：约 **6/10**
- Swift 原生主体中嵌入 Godot（仅为特效）：**不推荐**，复杂度大于收益

引擎不会自动让游戏更好玩；品质取决于谜题、触控、内容、修复反馈与叙事。Godot 改善的是“表现与制作流程”。

### Godot 能提升什么

1. **修复动画与视觉表现**：粒子/笔触/扫描/溶解/光晕、镜头移动、Shader 与 Tween 同步，且可在编辑器可视化迭代。
2. **棋盘渲染**：官方将“大量简单对象组成的网格或棋盘”列为自定义 2D 绘制的典型用途，可避免每格一个节点的开销 —— 见 [Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)。
3. **跨平台**：若未来确定同时上 Android / 桌面 / Web，Godot 收益显著。
4. **快速可玩原型**：适合验证棋盘手感、修复成就感与转场氛围。

### 为什么现在不全面采用 Godot

本项目更接近“内容型 iOS 应用 + 定制棋盘 + 克制游戏化表现”，而非高实时性游戏。现有规划大量依赖 Apple 原生能力：SwiftUI 页面/导航、SwiftData 可靠存档、StoreKit 2 权益与购买恢复、Share Sheet/PNG/PDF 导出、Dynamic Type/VoiceOver/Switch Control、Apple Pencil 与复杂触控、MetricKit/TestFlight/XCUITest。

Godot 能导出 Xcode 工程并发布 iOS（见 [Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)），也有 StoreKit / iCloud 等 iOS 插件机制（见 [Plugins for iOS](https://docs.godotengine.org/en/4.6/tutorials/platform/ios/plugins_for_ios.html)），但这些通常意味着额外的插件维护、异步桥接与真机测试，不如 Swift 原生直接。

**最大风险是无障碍。** 项目要求 VoiceOver 完整业务路径、棋盘逐行/逐格导航、Voice Control、Switch Control、Full Keyboard Access、Reduce Motion、Dynamic Type。Godot 已提供 `AccessibilityServer`（含表格/单元格/焦点/动作/屏幕阅读器语义，见 [AccessibilityServer](https://docs.godotengine.org/en/stable/classes/class_accessibilityserver.html)），但“有 API”不等于自定义棋盘能自然达到 iOS 无障碍质量，必须真机专项验证；SwiftUI 在这点上风险明显更低。

### 推荐路线

- **主路线：继续 Swift 原生。** 页面用 SwiftUI；棋盘用 Canvas/Core Graphics（必要时桥接 UIKit）；完成动画用 Core Animation 或 SpriteKit；存档 SwiftData；权益 StoreKit 2；音频/触觉 AVFoundation + Core Haptics；内容验证用独立 Swift Package/CLI。
- **不要**只为粒子动画就在 Swift 应用里嵌入 Godot —— 两套生命周期/渲染/输入/构建流程会显著增加维护成本；SpriteKit 已足够。
- **重新考虑全 Godot 的条件**（满足任意两项）：Android 与 iOS 同期首发；桌面/Web 成为确定目标；动画表现升级为核心卖点；团队对 Godot/GDScript 明显更熟练；可降低完整原生无障碍要求；愿意维护 StoreKit / 分享 / PDF / 辅助功能的原生插件。

### 验证方式（M0 技术尖峰，≤1 周）

用同一个垂直切片验证 Godot：25×25 棋盘稳定 60fps；拖动轴锁定 + 双指缩放/平移 + 单一 Undo 事务；进入后台与强制结束后可靠恢复；VoiceOver 逐行/逐格；StoreKit 购买恢复与离线权益；PNG/PDF 分享；一次 Fragment 修复融合动画。达标且 Android 已成硬需求，再考虑改路线；否则继续 Swift。

## 3. World Labs（画境实现）评估

### 能力核实（2026-09）

World Labs 的 **Marble** 可从文本、单图/多图、视频或粗略 3D 布局生成**可持续探索的 3D 世界**，并支持交互式编辑、扩展与组合，导出为 Gaussian splats、网格或视频 —— 见 [Marble: A Multimodal World Model](https://worldlabs.ai/blog/marble-world-model)。**World API** 可从文本/图像/全景/多视角/视频程序化生成可导航空间，用于 Web 渲染或接入交互系统 —— 见 [Announcing the World API](https://www.worldlabs.ai/blog/announcing-the-world-api)。

**与本项目高度吻合的官方案例：**

- [Musée du Monde](https://www.worldlabs.ai/labs/showcase/musee-du-monde)：以博物馆为中枢，走近画作即穿过“传送门”进入由该画生成的可探索世界，场景间实时串流并交叉淡入。
- [Painted Time](https://www.worldlabs.ai/labs/showcase/painted-time)：把一幅历史画作生成为可行走的 Gaussian splat 世界，并叠加基于 Web Audio API 的空间化环境声（水声、钟声、海鸥）。

也就是说，“进入画里”在技术上已有可运行的视觉原型。

### 建议：把 Marble 作为离线内容生产工具

```text
原始画作
  → Marble 生成画境
  → 美术人工调整
  → 导出 Splat / Mesh / 360 图
  → 简化碰撞与移动范围
  → 添加破损状态、热点与音频
  → 打包进游戏
```

**不建议首发让玩家在手机上实时调用 API 生成世界**，原因：网络与生成等待；输出不确定、难以完整测试；美术一致性问题；版权与商业授权管理；移动端文件大小与性能；无法保证破损位置精确对应 Nonogram；模型升级可能让同一关卡发生变化。

### 资产规格与优化提醒

Marble 导出规格：标准 splat 约 **200 万点**，低清约 **50 万点**；高质量网格约 **60 万–100 万三角形**（生成耗时可达一小时且有速率限制）—— 见 [Export file specs](https://docs.worldlabs.ai/marble/export/specs)。这些资产进入 iPhone/iPad 前**必须经过优化**，不能直接导入。导出还需注意坐标系（Marble 默认 OpenCV，多数 DCC 为 OpenGL，需对 Y/Z 轴取反）。导出需付费计划：Standard 覆盖 splat/360/碰撞网格，HQ 网格与商业授权需 Pro —— 见 [Exporting from Marble](https://docs.worldlabs.ai/marble/export/gaussian-splat)。

### V1 不要把每幅画都做成大型自由世界

先做**一幅“英雄画作”的垂直切片**：一个小型展厅 + 一幅可穿越的画 + 3–5 分钟有限画境探索 + 3 个真实破损点 + 5×5/10×10/15×15 三个谜题 + 每解一题实时恢复一部分 + 最后完整恢复画境与作品。画境不必开放世界，可用受控步行路径、360° 观察点、2.5D 纵深、少量交互热点、环境声与轻微动态、通过画框回到博物馆。这样能获得大部分代入感，同时避免项目从 Nonogram 变成昂贵的 3D 冒险。

## 4. 引擎选型与画境的关系（给 A-011 的输入）

- 若画境采用**离线生成 + 预烘焙资产 + 有限交互**（推荐），则 SwiftUI + SceneKit/RealityKit（或 SpriteKit 做 2.5D）可以承载，无需切换到 Godot。
- 若画境升级为**大范围自由漫游 + 实时 splat 渲染 + 多平台**，Godot 的性价比会上升，此时应把“Godot vs 原生 3D”一并纳入 A-011 决策，并用垂直切片原型验收（iOS 无障碍、StoreKit/恢复、复杂手势、内容工具链、性能、Android 复用、团队能力）。

## 5. 待决事项

- A-011：正式确定技术栈与最低系统、同步、分析、性能与测试范围。
- 画境实现层级：预烘焙有限交互 vs 实时自由漫游 —— 直接影响引擎选型与性能预算。
- Marble 商业授权与版权（与 A-009 素材/版权决策合并考虑）。
- 若引入 3D 画境，需补充 3D 无障碍方案（画境探索如何服务 VoiceOver/Switch Control 主路径）。

## 参考来源

- Godot：[Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html) · [Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) · [Plugins for iOS](https://docs.godotengine.org/en/4.6/tutorials/platform/ios/plugins_for_ios.html) · [AccessibilityServer](https://docs.godotengine.org/en/stable/classes/class_accessibilityserver.html)
- World Labs：[Marble 世界模型](https://worldlabs.ai/blog/marble-world-model) · [World API](https://www.worldlabs.ai/blog/announcing-the-world-api) · [Musée du Monde](https://www.worldlabs.ai/labs/showcase/musee-du-monde) · [Painted Time](https://www.worldlabs.ai/labs/showcase/painted-time) · [导出规格](https://docs.worldlabs.ai/marble/export/specs) · [导出/授权](https://docs.worldlabs.ai/marble/export/gaussian-splat)

> 说明：外部资料内容经改写以符合授权限制。
