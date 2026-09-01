# Kanaka 开发与 App Store 发布规划

> 状态：Draft v1
> 目标平台：iOS / iPadOS
> 架构原则：一个 App、两个可切换路径、一个共享内容与权益模型

## 1. 技术决策

| 层 | 选择 |
|---|---|
| 语言 | Swift 6.x |
| UI | SwiftUI |
| 棋盘 | SwiftUI `Canvas` + Core Graphics；复杂手势必要时桥接 UIKit |
| 游戏核心 | 独立 Swift Package：`KanakaCore` |
| 内容协议 | 独立 Swift Package：`KanakaContentKit` |
| 本地存储 | SwiftData；格子状态压缩为 `Data` |
| 内购 | StoreKit 2 |
| 音视频 | AVFoundation / AVKit |
| 动画 | SwiftUI / Core Animation；SpriteKit 仅按需 |
| 云同步 | V1.1 可选 CloudKit |
| 日志与性能 | OSLog、MetricKit、Xcode Organizer |
| 测试 | Swift Testing / XCTest / XCUITest |
| CI/CD | Xcode Cloud 或 GitHub Actions + TestFlight |

建议 Deployment Target 为 iOS 17 / iPadOS 17，并用 App Store 提交时 Apple 要求的最新 Xcode 与 SDK 构建。Apple 当前要求页面列明 Xcode 26+ 与相应 iOS/iPadOS 26 SDK：[Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)。部署目标不需要因此提高到 iOS 26。

## 2. 工程结构

```text
painting-nonogram/
├── Apps/
│   └── KanakaApp/
├── Packages/
│   ├── KanakaCore/
│   ├── KanakaContentKit/
│   └── KanakaDesignSystem/
├── Tools/
│   └── kanaka-content/
├── Content/
│   ├── Sources/
│   ├── Packs/
│   ├── Artwork/
│   ├── Localization/
│   └── Rights/
├── Resources/
│   ├── Audio/
│   ├── Video/
│   ├── UI/
│   └── Fonts/
├── StoreKit/
├── Tests/
├── Scripts/
└── docs/
```

素材生成方式不属于 App 架构。游戏只读取经过验收的答案蒙版、作品图、音频、视频和元数据。

## 3. 功能模块

### 3.1 `KanakaCore`

不依赖 SwiftUI、StoreKit 或 SwiftData：

- `PuzzleDefinition`
- `LineClue`
- `CellState`
- clue generator
- 唯一解 solver
- 可解释 hint step
- GameSession 状态机
- Undo/Redo transaction
- 完成判断
- bitset 编解码
- 难度基础评分

内容工具与 App 共用该包，避免关卡编译规则和客户端规则不一致。

### 3.2 `KanakaContentKit`

- `level-v1` / `pack-v1` Codable schema。
- 作品、fragment、蓝图和本地化模型。
- manifest 与资源引用校验。
- SHA-256 内容哈希。
- schema migration。
- 权利记录引用。

### 3.3 App Features

- `RestorationFeature`：章节、作品、棋盘、完成动画和故事进度。
- `WorkshopFeature`：蓝图库、材料、导出和直接解锁。
- `GalleryFeature`：收藏展示和档案卡。
- `PurchaseFeature`：产品、交易、恢复购买和 entitlement。
- `SettingsFeature`：音频、触觉、错误提示、无障碍和隐私。

它们属于同一个 App target，共享：

- `ContentStore`
- `ProgressStore`
- `EntitlementStore`
- `ArtworkRepository`
- `BlueprintRepository`

### 3.4 蓝图权限计算

```swift
struct BlueprintAccess {
    let solvedArtwork: Bool
    let purchasedEntitlement: Bool

    var canViewProductionFiles: Bool {
        solvedArtwork || purchasedEntitlement
    }

    var hasRestorerSeal: Bool {
        solvedArtwork
    }
}
```

实际代码应使用稳定 ID 和可测试的 entitlement resolver。不要在两个页面分别实现权限判断。

## 4. 数据模型

### 4.1 内容实体

- `Chapter`
- `Artwork`
- `Fragment`
- `PuzzleDefinition`
- `Blueprint`
- `MaterialList`
- `ArchiveEntry`
- `ContentPack`

### 4.2 玩家实体

- `LevelProgress`
- `ArtworkProgress`
- `InProgressSession`
- `StoryState`
- `UserPreferences`
- `PurchaseEntitlementCache`

### 4.3 状态边界

- 购买只修改 entitlement。
- 解谜完成同时修改 level、artwork 和 story progress。
- 蓝图可用性由进度或 entitlement 派生，不作为唯一真相单独手工写入。
- 购买蓝图后不生成虚假的 level completion。
- 内容升级时按稳定 ID 与 content hash 迁移。

## 5. 内容输入规范

每个 fragment 至少包含：

```text
fragment-001/
├── solution.png       # 精确等于棋盘尺寸的二值蒙版
├── restored.png       # 彩色完成图
├── damaged.png        # 受损图
├── thumbnail.png
└── metadata.json
```

规则：

- `solution.png` 不允许抗锯齿和半透明。
- 左上原点，row-major。
- 黑/透明为空，白为 Filled。
- 必须人工检查小尺寸轮廓。
- 大型作品另有归一化 fragment 坐标。

## 6. 关卡编译工具

建立 macOS Swift CLI：`kanaka-content`。

```text
validate-source
→ compile-levels
→ generate-clues
→ solve-and-score
→ validate-assets
→ build-pack
→ write-manifest-and-hashes
```

每一关发布前必须：

- 答案尺寸正确。
- clues 重算一致。
- 恰好一个解。
- 可纯逻辑完成。
- 资源和本地化完整。
- ID/revision/hash 合法。
- 人工试玩记录存在。
- 权利记录存在。

失败时命令返回非零并拒绝生成发布 pack。

## 7. 棋盘实现

### 7.1 渲染

- 单个 Canvas/自定义 UIView，不使用每格一个 View。
- 绘制顺序：背景 → clue → 分隔线 → 格子状态 → 交互预览 → 辅助提示。
- 5 格主线和普通格线按缩放级别调整。
- 缓存静态 clue 与网格层。
- 只更新 dirty rect。

### 7.2 交互

- `BoardTransform` 负责逻辑/屏幕坐标转换。
- 所有输入共享命中测试函数。
- 拖动起始动作在 transaction 内保持一致。
- 两指手势取消正在进行的绘制。
- 防止同一格在一次拖动中被重复切换。
- 触觉在设置关闭后完全停止。

### 7.3 存档

- 每格 2 bit：unknown / filled / excluded / reserved。
- 自动保存采用短节流，进入后台立即 flush。
- 记录关卡 content hash。
- 不把每格建成 SwiftData object。

## 8. 蓝图输出

V1 建议支持：

- App 内高清网格查看。
- PNG 导出。
- 分页 PDF。
- 色号、数量、总豆数和底板布局。
- 系统 Share Sheet。

CSV 可根据用户研究决定。导出文件生成在临时目录，分享完成后清理。文件名不包含用户个人信息。

## 9. StoreKit 设计

使用 StoreKit 2：

- 非消耗型完整修复版。
- 少量非消耗型工坊蓝图权益或主题包。
- 必要时提供从修复版升级工坊权益的产品。
- 监听 transaction updates。
- 验证 entitlement。
- 支持恢复购买。
- 价格显示使用 StoreKit 返回的本地化价格。
- 已验证购买在离线时继续可用。

具体商品数量应在垂直切片测试后冻结，避免过早建立大量 SKU。Apple 提供 StoreKit 作为数字内容购买机制：[StoreKit](https://developer.apple.com/storekit/)。

## 10. 隐私与网络

V1 默认：

- 无账号。
- 无广告 SDK。
- 无 IDFA 和跨 App 跟踪。
- 不申请照片、位置、联系人和麦克风权限。
- 不上传玩家棋盘。
- 内容内置，离线可玩。

使用第三方 SDK 前审查：

- 数据收集。
- Privacy Manifest。
- required-reason API。
- 数据保留和删除。
- 儿童/地区要求。

App Store Connect 的隐私申报必须与实际二进制一致：[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)、[Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements)。

## 11. 无障碍实现

- Dynamic Type 覆盖非棋盘 UI。
- 高对比度、深色界面、非仅颜色表达。
- Reduce Motion 环境值驱动所有关键动画替代方案。
- VoiceOver 的行/列/格状态描述。
- 棋盘自定义 actions：填色、排除、擦除、移动。
- 工坊材料表采用语义列表，而不是只显示图像。
- 导出前信息可由 VoiceOver 完整读取。

只有用户能完成常见任务时才申报对应无障碍标签：[Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)。

## 12. 测试

### 12.1 核心测试

- clue generation。
- 唯一解、多解、无解。
- 空行、满行、矩形和最大尺寸。
- bitset round trip。
- GameSession 操作序列。
- Undo/Redo。
- hint 合法性。
- 完成判定。
- entitlement resolver。

### 12.2 内容测试

每次构建对全部 pack 运行：

- schema。
- solver。
- clue re-computation。
- 资源引用。
- 本地化 key。
- ID/revision/hash。
- rights record。

### 12.3 UI 测试

- 首次启动先完成共同故事背景，再出现路径选择。
- 学徒成长与专业画师在选择页面和首页层级平等。
- 选择只改变首次教学和默认落点，不锁定功能。
- 修复室与工坊自由切换。
- 中途退出和恢复。
- 完成作品后蓝图出现。
- 购买蓝图后谜题仍未完成。
- 后续解谜后出现亲手修复印章。
- 购买、失败、恢复购买。
- Reduce Motion、Dynamic Type、VoiceOver 关键路径。

### 12.4 性能目标

- 冷启动到可交互主界面目标 2 秒内，不含可跳过开场。
- 棋盘操作目标 60 fps。
- 单关解码和恢复目标 200 ms 内。
- 后台/终止不丢进度。
- 不一次加载整章所有大图。

## 13. CI/CD

### Pull Request

- Swift build。
- Core/Content 单元测试。
- 全量内容 validator。
- App 无签名 build。
- 格式与静态检查（团队确定后启用）。

### Release Candidate

- iPhone/iPad UI tests。
- StoreKit Configuration tests。
- 内容包完整性。
- PrivacyInfo、本地化和资源检查。
- Archive 并上传 TestFlight。

### 发布

- 证书和 App Store Connect API key 只在 secrets。
- 不提交生产密钥。
- Release 使用不可变 tag。
- 记录 App 版本、pack 版本和 commit。

## 14. 开发阶段

### M0：规则与范围冻结（1–2 周）

- 确认单 App 双路径。
- 冻结 Classic Nonogram 规则。
- 确认首发内容和商业模型候选。
- 完成流程 wireframe。
- 定义 schema。
- 选择 10 个素材。

通过：所有进度、蓝图和购买状态有唯一规则。

### M1：核心与内容工具（3–4 周）

- KanakaCore。
- clue generator。
- solver。
- validator。
- `kanaka-content` CLI。
- 首批 10 个关卡。

通过：10 个答案蒙版一键生成唯一解关卡；错误内容无法构建。

### M2：技术原型（3–4 周，可部分并行）

- App shell。
- Canvas 棋盘。
- 填/X/擦除。
- 拖动、缩放、平移。
- Undo/Redo。
- SwiftData 存档。

通过：iPhone/iPad 真机稳定游玩并恢复进度。

### M3：垂直切片（4–6 周）

- 开场与共同故事背景。
- 平等路径选择：学徒成长 / 专业画师。
- 修复室与工坊。
- 15–20 关。
- 一幅大型作品。
- 蓝图查看和导出。
- StoreKit 测试权益。
- 音频、触觉、基础无障碍。

通过：新用户先理解共同故事，再平等选择学徒成长或专业画师；选择只影响初始教学，之后能在同一 App 中自由切换并共享作品。

### M4：完整 V1（8–10 周）

- 100–150 关。
- 三章。
- 3–5 幅大型作品。
- 完整工坊。
- 商业化、本地化、权利台账。

通过：Feature Complete；全部关卡自动验证和人工试玩。

### M5：TestFlight（3–4 周）

- 内部 Alpha。
- 20–50 人小规模测试教学、触控和双路径理解。
- 100–300 人扩大稳定性测试。
- 调整难度、权益描述和付费页。
- 准备 App Store metadata。

Apple 支持通过 TestFlight 邀请外部测试者：[TestFlight external testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)。

通过：Release Candidate 连续 7 天无 P0/P1；购买、恢复、进度和蓝图导出无阻断。

### M6：审核与发布（2–3 周）

- 提交 App 和内购。
- 审核备注说明两个入口、免费/付费边界与恢复购买。
- 分阶段或手动发布。
- 监控崩溃、购买失败、评论和支持请求。

## 15. 团队与周期

推荐：

- iOS 工程师 1–2。
- 游戏/产品设计 0.5–1。
- UI/视觉设计 0.5–1。
- 内容设计/关卡 QA 1–2。
- 音频兼职/外包。
- 后期 QA/发布 0.5–1。

估算：

- 3–5 人并行：20–26 周。
- 1 名主工程师 + 兼职设计/内容：8–12 个月。
- 垂直切片：8–12 周。

## 16. 前四周任务

### 第 1 周

- 建立 Swift Package 与 App 工程。
- 定义 `level-v1` / `pack-v1`。
- 冻结单 App 双路径状态模型。
- 准备 10 个二值答案蒙版。

### 第 2 周

- clue generator、bitset、validator。
- solver 初版。
- 棋盘低保真原型。
- Artwork/Blueprint 数据模型。

### 第 3 周

- solver 和内容 CLI。
- 编译 10 个关卡。
- App 读取 pack。
- Entitlement resolver。

### 第 4 周

- Canvas 棋盘完整操作。
- 本地存档。
- 简化修复室/工坊切换。
- 完成后蓝图授权。
- 模拟直接购买但不完成故事的状态测试。
- iPhone/iPad 真机验收。

四周成功标准：

> 10 个现成素材可以编译成唯一解关卡；用户能在一个 App 中从修复室完成作品并获得蓝图，也能在工坊模拟直接获得蓝图，而两种方式不会混淆谜题和故事进度。

## 17. App Store 清单

- Apple Developer Program、Bundle ID、App Store Connect 记录。
- StoreKit 商品、税务和银行协议。
- iPhone/iPad 真实玩法截图。
- 简中、繁中、英文 metadata。
- 隐私政策与支持 URL。
- App Privacy。
- `PrivacyInfo.xcprivacy`。
- Accessibility Nutrition Labels。
- 年龄分级问卷。
- 素材、字体、音频、视频和作品权利记录。
- 审核说明和恢复购买路径。

Apple 审核要求以最新 [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 为准。年龄分级需按实际灾后画面回答：[Age rating definitions](https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions)。

## 18. 发布阻断条件

- 崩溃或存档丢失。
- 多解、无解或 clue 错误。
- 购买后未获得蓝图。
- 直接购买错误推进故事。
- 完成作品后未授予蓝图或亲手修复印章。
- 恢复购买失败。
- 主要无障碍路径不可完成。
- 隐私申报与实际行为不一致。
- 素材权利记录不完整。

## 19. 后续路线

### V1.1

- CloudKit 进度同步。
- 日文本地化（若未首发）。
- 免费新增作品。
- VoiceOver 棋盘增强。

### V1.5

- 主题蓝图包。
- 新章节。
- 可选 Game Center 成就。
- 签名内容包下载。

### V2

- 彩色 Nonogram。
- 织物、地图、手稿和壁画。
- 每日档案。
- 根据真实市场决定 Android。

---

外部官方资料均已重新表述；正式提交前应再次核对 Apple 当时生效的要求。
