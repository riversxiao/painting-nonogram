# Kanaka / Painting Nonogram

Kanaka 是一款面向 iPhone 与 iPad 的叙事型 Nonogram 游戏。玩家在“长夜”后的文明修复署工作，通过行列线索修复作品中真实受损的局部，并获得真正可以制作的整幅拼豆蓝图。

## 一个 App，两条平等路径

首次启动先介绍“长夜”和文明修复署，随后用一局可明确跳过的 `5×5` 共同教学解释 Nonogram。完成或跳过教学后，用户可选择初始落点，并随时切换：

- **学徒成长 / 修复室**：解开 Nonogram、恢复作品、推进故事并亲手获得蓝图。
- **专业画师 / 拼豆工坊**：使用已获得或已被授予权限的蓝图，查看色号、材料并导出制作文件，也可随时回到修复室。

两条路径共享内容、进度与权益。蓝图库权益不会完成谜题、改变作品状态、推进 Gallery/Chapter、Museum 或故事进度，也不会授予“亲手修复”印章。

## 内容与完成规则

```text
Museum
└─ Gallery（承载 Chapter 叙事；Museum 1 可 1:1 映射）
   └─ Artwork
      └─ 1–4 Repair Fragments
         └─ 每个 Fragment 对应一个真实破损区域和一个 Nonogram
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

## Museum 1 首发规划

A-005 与垂直切片验证前，Museum 1 使用以下制作包络：

- `3` 个 Galleries：静默展厅、烟痕画廊、水下档案。
- `12–18` 幅 Artworks。
- `20–30` 个 Repair Fragment puzzles。
- 制作基线：`15` 幅 Artworks / `24` 个 puzzles。
- 基线示例分布：`9×1、4×2、1×3、1×4`，仅用于估算内容生产，不是商店承诺。
- `5×5`、`10×10`、`15×15`、`20×20`，少量 `25×25`。
- 简体中文、繁体中文、英文；日文视 A-005 与预算验证结果决定。

首批验证内容使用两个明确口径：

- `M1-CANDIDATE-10`：由 `bead-gen` 产出的约 `10` 幅完整 2D 候选 Artwork，用于 Museum 1 策展、画境与谜题可行性评估。
- `VS-PUZZLE-10`：当前项目从候选作品中定义的约 `10` 个 Repair Fragment / PuzzleDefinition 技术样本，用于覆盖 1、2、3、4 Fragment 边界与整幅完成流程。

两者均不代表首发规模。

## 推荐技术栈

- Swift 6.x、SwiftUI
- SwiftUI `Canvas` + Core Graphics 棋盘
- SwiftData 本地进度
- StoreKit 2 权益
- AVFoundation 音频与视频
- OSLog、MetricKit、Swift Testing / XCTest / XCUITest

游戏工程只读取经过验收的图片、答案蒙版、视频、音频和元数据，不依赖素材生成仓库或生成模型。

## 文档

- [产品对齐决策](docs/ALIGNMENT_DECISIONS.md)
- [故事圣经](docs/STORY.md)
- [游戏设计文档](docs/GAME_DESIGN_DOCUMENT.md)
- [作品资产、章节编排与内容生产规范](docs/CONTENT_CURATION.md)
- [世界观扩展：画境、画桥与文明消除](docs/NARRATIVE_EXPANSION.md)
- [技术探索：Godot 与 World Labs](docs/TECH_EXPLORATION.md)
- [开发与 App Store 发布规划](docs/DEVELOPMENT_PLAN.md)

## 当前状态

项目处于前期设计与技术规划阶段。首个工程目标是先导入 `M1-CANDIDATE-10`，再用 `VS-PUZZLE-10` 验证：

```text
内容导入 → schema 与区域校验 → 唯一解验证 → iPhone/iPad 游玩
→ Fragment x/n → 最后一块触发整幅恢复 → 蓝图权限与印章正确派生
```
