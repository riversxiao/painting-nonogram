# `puzzle-definition-v1` 规则与语义哈希规范

> 状态：V1 schema、正式题无预填边界、彩色 clue 规则、唯一解门、纯逻辑 solver v1 与 puzzle semantic hash 已冻结。

## 1. JSON 契约

`puzzle-definition-v1` 是一个 Repair Fragment 的彩色 Nonogram 事实源。答案只来自 JSON semantic grid；PNG 仅可作为派生调试资源。

必填字段：

- `schema = puzzle-definition-v1`；
- 稳定 `id` 与从 `1` 开始的 `revision`；
- `kind = formal | tutorial | demonstration | accessibility`；
- `rulesVersion = colored-nonogram-v1`；
- `solverVersion = line-candidate-intersection-v1`；
- 1-based、连续且最多 `254` 色的 palette `colorIndex` 到稳定 `colorId` 映射，同时提供 `sRGB8` 和唯一非颜色辅助符号；
- 左上原点、row-major 的 `solution`，宽高均为 `1...25`；`cells` 中 `null` 表示 empty，字符串表示稳定 `colorId`；
- 由答案确定性生成的行列 `(count, colorIndex)` clues；
- `prefilledCells`；正式题必须为空数组，其他 kind 可记录作者预填约束；
- `semanticHash`。

同色 clue 段至少相隔一个 empty；异色段可直接相邻。正式题必须在无预填条件下仅凭 clues 和规则具有唯一精确彩色解，并由指定纯逻辑 solver 完成。

教学、演示和无障碍流程中的动态揭示属于具体游玩 Session 的 assistance，不修改正式 PuzzleDefinition；任何使用 assistance 的完成都不计 `completedWithoutHints`。

## 2. Puzzle semantic hash

哈希输入不是整个 PuzzleDefinition，而是以下语义投影：

```json
{
  "height": 5,
  "palette": [
    {"colorId": "archive-blue", "colorIndex": 1}
  ],
  "prefilledConstraints": [],
  "rulesVersion": "colored-nonogram-v1",
  "schema": "puzzle-semantic-v1",
  "solution": [null, "archive-blue"],
  "width": 5
}
```

规范化规则：

1. 对象 key 以 JCS 的顺序输出，不写空白；本投影的 key 均为 ASCII。
2. palette 按 `colorIndex` 升序；`colorIndex` 必须从 1 连续递增。
3. solution 保持完整 row-major 顺序。
4. authored prefilled constraints 按 `(y, x)` 排序；正式题恒为空数组。
5. 字符串按 JSON 规则转义；本投影只允许 string、integer、null、array 和 object。
6. 对 canonical UTF-8 bytes 计算 SHA-256，写成 `sha256:<lowercase hex>`。

参与哈希：尺寸、规则版本、palette 的 `colorIndex ↔ colorId` 语义映射、完整答案及 authored prefilled constraints。

不参与哈希：`id`、`revision`、`kind`、solver 版本/报告、派生 clues、sRGB 显示值、辅助符号、难度、标题和调试资源。它们发生变化时必须重新校验，但只有参与语义投影的字段变化才改变 puzzle semantic hash。语义 hash 变化必须创建新的 puzzle revision，旧玩家格状态不得静默套用。

## 3. Solver 与发布门

发布校验依次执行：

1. schema、ID、revision、尺寸、palette、坐标、prefilled policy；
2. 从 semantic grid 重算 clues 并与声明值逐项比较；
3. 重算 semantic hash；
4. 通过精确彩色求解器证明解数恰为 1，并与 semantic grid 完全一致；
5. 通过 `line-candidate-intersection-v1` 纯逻辑 solver 完成，输出可解释步骤。

纯逻辑 solver v1 使用确定性行列可行值交集：通过有限状态自动机的前向/后向动态规划计算当前约束下每格在全部合法排列中的可取值，不物化排列集合；对只剩一个可取值的格进行行列交替传播，直至完成或停滞。禁止猜测、分支或以目标答案反推步骤。精确 solver 复用同一动态规划约束传播，仅在仍有多个可取值时分支，并把计数截断为 `0 / 1 / 至少 2`。不能由逻辑 solver v1 完成的正式题不得发布；扩展推理能力必须使用新的 solver version 并重新生成报告。
