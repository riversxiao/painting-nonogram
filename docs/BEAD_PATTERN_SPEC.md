# `bead-pattern-v1` 资产交接规范

> 状态：`bead-pattern-v1` schema、坐标、颜色和 hash 契约已冻结；玩家进度迁移的具体产品政策仍待最终确认。
> 用途：定义 `bead-gen` 向 `painting-nonogram` 交付完整拼豆作品的唯一语义事实源。PNG、JPG、PDF、Nonogram clues、运行时二进制和预览均由本规范的 JSON 派生。

## 1. 边界

`bead-pattern-v1` 描述**完整恢复版 Artwork**，不描述受损画面、Repair Fragment、Nonogram 进度、Gallery 编排或 3D 画境。职责链为：

```text
bead-gen
  → bead-pattern-v1 JSON + 预览 + provenance
  → painting-nonogram 验收、策展、破损设计与谜题生产
  → Blueprint / 运行时内容包 / 固定画境
```

App 不依赖 `bead-gen` 的代码、服务或模型。接收方必须能够只凭已验收的静态交付包离线重建网格与材料统计。

## 2. 坐标、网格与颜色语义

- 原点位于左上角；`x` 向右，`y` 向下。
- `cells` 按 row-major 展平，长度必须等于 `width × height`。
- `0` 表示空格；非零整数表示 `palette[]` 的 1-based index。
- palette 顺序不是颜色身份。跨版本身份由稳定 `colorId` 表示。
- 每个 palette entry 必须给出精确 `sRGB8`、商业拼豆品牌、色号和色卡版本；Museum 1 的每幅 Artwork 都会生成 Blueprint，因此不允许缺省品牌映射。
- `accessibilitySymbol` 必须是唯一的单个扩展字素（一个用户可见字符）；它是网格与导出中的稳定非颜色编码，不允许空值或多字符标签。
- 不允许用相近 RGB 自动合并稳定 `colorId`；颜色替换必须形成显式修订。
- 透明度不承载网格语义；空格只由 cell 值 `0` 表示。

## 3. JSON 契约

```json
{
  "schema": "bead-pattern-v1",
  "assetId": "m1-artwork-001",
  "revision": 1,
  "title": "晨光下的餐桌",
  "grid": {
    "origin": "top-left",
    "order": "row-major",
    "width": 58,
    "height": 58,
    "cells": [0, 0, 1, 1, 2]
  },
  "palette": [
    {
      "colorId": "warm-white",
      "name": {"zh-Hans": "暖白", "en": "Warm White"},
      "sRGB8": {"r": 242, "g": 233, "b": 214},
      "brand": {
        "name": "example-brand",
        "code": "E01",
        "swatchVersion": "2026-01"
      },
      "accessibilitySymbol": "A"
    }
  ],
  "physical": {
    "beadPitchMm": 5.0,
    "boardLayout": {"columns": 2, "rows": 2, "boardWidth": 29, "boardHeight": 29}
  },
  "generator": {"name": "bead-gen", "version": "1.0.0"},
  "provenance": {
    "sourceType": "original",
    "sourceRef": "rights/m1-artwork-001.json",
    "commercialUseCleared": true
  },
  "contentHash": "sha256:<hex>"
}
```

示例中的 `cells` 为节选，正式文件必须包含完整网格。

### 3.1 必填字段

| 字段 | 规则 |
|---|---|
| `schema` | 固定为 `bead-pattern-v1` |
| `assetId` | 稳定逻辑资产 ID，不随标题、revision 或目录变化；`(assetId, revision)` 全局唯一 |
| `revision` | 从 1 开始递增的整数；同一 `assetId` 下必须单调递增 |
| `grid` | 固定坐标系、宽高与完整 row-major cells |
| `palette` | 所有被引用 index 的稳定颜色记录 |
| `physical` | 豆间距、底板尺寸与布局，可计算完成尺寸 |
| `generator` | 生成器名称和精确版本 |
| `provenance` | 来源、权利引用及商业使用状态 |
| `contentHash` | 按第 4 节生成的内容哈希 |

本地化标题允许为空；palette 的 `colorId`、`sRGB8`、完整品牌映射与非颜色辅助符号均不可缺失。

## 4. Canonical hash

`contentHash` 使用 SHA-256：

1. 从文档中移除顶层 `contentHash` 字段；
2. 按 RFC 8785 JSON Canonicalization Scheme（JCS）生成 canonical JSON；
3. 对 canonical JSON 的 UTF-8 bytes 计算 SHA-256；
4. 写成 `sha256:<lowercase hex>`。

禁止对格式化后的普通 JSON、PNG 像素或压缩包直接取 hash 代替上述 canonical hash。`contentHash` 是完整 canonical 文档的 **bead asset hash**：除 `contentHash` 自身外，标题、revision、generator、网格、palette、物理规格与 provenance 等全部字段都参与计算。任一参与字段变化都必须递增 bead revision 并产生新 hash；这不等于谜题答案发生变化。编译器必须重算并拒绝不匹配的交付物。

项目中区分三类 hash：

- **bead asset hash**：完整 `bead-pattern-v1` canonical 文档的身份；除 `contentHash` 外全部字段参与；
- **Blueprint hash**：交付给玩家的网格、材料、版面和导出规则身份；
- **Puzzle semantic hash**：某个 Repair Fragment 的彩色答案、规则版本与 palette 语义身份。

三者可以引用同一来源，但不得混用。

## 5. 派生产物

| 产物 | 地位 | 规则 |
|---|---|---|
| PNG | 派生 | 可用于高清网格或预览；不得成为语义事实源 |
| JPG | 派生 | 仅作有损预览，不用于取色、计数或答案 |
| PDF | 派生 | 可选分页打印能力；事实源不得依赖 PDF |
| materials JSON/CSV | 派生 | 从 grid + palette 重新统计 |
| Nonogram clues | 派生 | 从 Repair Fragment 的彩色语义答案生成 |
| runtime binary | 派生 | 必须记录来源 hash 与编译器版本 |

任何派生产物都必须能追溯到 `assetId`、`revision` 与 `contentHash`。

## 6. Blueprint V1 契约

`bead-pattern-v1` 是完整 Artwork 网格与材料语义的**上游事实源**；`blueprint-v1` 是玩家可使用生产资料的规范事实源。Blueprint 必须由某个明确的 bead asset revision 确定性生成，并保存：

- `schema = blueprint-v1`、稳定 `blueprintId`、`revision`；
- `artworkId`；
- `sourceBeadAsset = { assetId, revision, contentHash }`；
- 完整彩色 `grid` 与完整 `palette`（稳定 color ID、精确 sRGB8、品牌、色号、色卡版本、辅助符号）；
- `materialCounts`、`totalBeads`；
- 完成尺寸、豆间距和底板布局；
- `exportRules`，至少固定 PNG 网格尺寸、坐标/图例规则和文件命名版本；`pixelsPerCell` 不得低于 8，以保证每个占用格中的单字素辅助符号可辨识；
- `blueprintHash`。

`blueprintHash` 的计算方式与 bead asset hash 相同：移除顶层 `blueprintHash`，对剩余 `blueprint-v1` 完整文档执行 RFC 8785/JCS，再对 UTF-8 bytes 计算 SHA-256。所有上述字段都参与 hash；修改任何生产语义或导出规则必须递增 Blueprint revision。编译器必须验证 Blueprint 的 grid/palette/physical 与其 `sourceBeadAsset` 一致，并重新统计材料数量。

V1 用户能力固定为 App 内高清网格、PNG、材料清单和系统 Share Sheet。分页 PDF 是可选 capability，可根据成本进入 V1 或 V1.1；JPG 只可作为展示预览。

## 7. 校验与版本策略

导入必须拒绝：未知 schema、重复 `(assetId, revision)`、同一 `assetId` 下非递增 revision、网格长度错误、cell index 越界、重复 `colorId`、缺失 sRGB8、缺失或无效品牌映射、无法计算物理尺寸、权利未清、hash 不符。内容清单必须显式指定每个 `assetId` 的 active revision；回滚也必须通过清单变更完成，不允许按“最大 revision”静默切换。

版本安全边界已冻结：

- bead 文档任一参与 hash 的字段变化都递增 bead revision；
- 仅标题、本地化或 provenance 等文档字段变化会改变 bead asset hash；派生 PNG/JPG 预览文件不在 `bead-pattern-v1` 文档中，其字节变化不改变 bead revision 或 `contentHash`；无论 bead asset hash 是否变化，只要 puzzle semantic hash 不变，就不影响 puzzle progress；
- palette 身份、网格答案或规则语义变化时，必须创建新的 puzzle revision 与 semantic hash；
- 不得静默把旧格子状态解释成新颜色或新答案。

玩家进度的具体迁移政策仍待最终确认。当前候选方案是：进行中的旧 revision 重置并提示；已完成记录保留为 `completedLegacyRevision`，继续认可成就并允许重玩新 revision。该候选不得在确认前被视为发布硬门或用户已同意的记录政策。

## 8. 生产建议（不属于协议硬限制）

Museum 1 可优先把完整网格统一为 `58×58`（`2×2` 块 `29×29` 底板）以降低材料和导出复杂度；构图需要时可使用矩形。该尺寸是首批生产建议，不是 `bead-pattern-v1` 的格式限制，需在首批实物与 Blueprint 打印验证后冻结。
