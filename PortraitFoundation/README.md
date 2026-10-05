# PortraitCore — 地基

一个跨平台人像修图 App 的**声明式修饰模型**。Mac / iPad / iPhone 三端共用，是整个方案里唯一不能设计错的东西。

```
Sources/PortraitCore/
  JSONValue.swift     任意 JSON 的无损容器 —— 前向兼容的载体
  RetouchOp.swift     文档模型、算子、锚点、校验、渲染契约
Tests/PortraitCoreTests/
  RetouchOpTests.swift
Sources/RetouchKit/
  SkinRenderer.swift  版本化 CPU 磨皮参考实现
Tests/RetouchKitTests/
  SkinRendererTests.swift
```

已验证：Swift 6 严格并发下构建通过，数据模型、渲染、分析与 MCP 事务均有自动测试；库与原型宿主均通过 iOS arm64 编译。实际运行结果见 `STATUS.md`。

---

## 为什么先做这个

因为其余三件事全都建立在它上面：

| 想做的事 | 依赖 RetouchOp 的什么 |
|---|---|
| **AI 直接控制软件** | 栈是纯数据 → MCP 工具只是几十行映射，不需要跨进程桥 |
| **一键预设** | 预设 = 栈的一个切片，不需要 AI 也能成立 |
| **三端同步** | 栈可序列化 → 手机读 Mac 编辑的结果 |
| **批量同步** | 每个算子声明 `syncBehavior`，决定"同步到所有"会不会毁片 |
| **非破坏 + 撤销** | 每个算子是一个独立 undo step |
| **算法持续改进** | `processVersion` 让旧文档保持旧渲染 |

如果这些不是从第一天就成立，后期无论怎么包装都补不回来。

---

## 五条不可妥协的规则

### 1. 算子描述**意图**，不描述算法

`skin(method:)` 里的 `method` 默认是 `.automatic`——意思是"把皮肤弄好看"，不是"频率分离"。

否则你每次改进磨皮算法，都会悄悄改变（或破坏）用户存过的每一个预设。`PortraitDocument.processVersion` 是配套的安全阀：老文档继续按老方式渲染，只有新编辑用新行为。

### 2. 栈按**相位**排序，不按用户顺序

修图师的心智顺序是「修形 → 磨皮 → 光影 → 调色」。允许随意插入会产生"先锐化后降噪""脸在磨皮之后才被液化"。

每个算子声明 `phase`，引擎**稳定排序**——同相位内保留添加顺序。

### 3. 区域是**锚定**的，不是按像素寻址的

一颗痘在「左脸颊关键点右 0.08、上 0.03」，不是 `(1423, 891)`。

这才让痘点能挺过重新检测、挺过裁剪、并且作为预设的一部分迁移到同一人的另一张照片。

### 4. **可创作性 ≠ 可渲染性**

用 Pencil 在 iPad 上手绘的 Dodge & Burn 光影图，必须能在没有笔的 iPhone 上**一模一样地渲染**。

所以每个算子在所有平台都全保真渲染；`authoringRequirement` 只告诉 UI **要不要在这个设备上提供编辑入口**。这一条直接解决了"iPhone 可以不做需要笔的功能"——不是靠砍功能，而是靠把"编辑"和"渲染"分开。

### 5. 不认识的算子在往返中**存活**

三端更新节奏不同。旧版 iPhone 打开新版 iPad 写的文档，必须**原样保留**它看不懂的算子——不丢弃，也不拒绝整个文档。

这就是 `RetouchOpKind.unsupported` + `JSONValue` 存在的唯一理由。`RetouchOpKind` 的 `Codable` 是**手写双向**的，因为合成的版本会在遇到未知 case 时直接抛错——那正好是必须活下来的那个场景。

> 作为对照：Compositor 的 `.comp` 加载器在 `version > current` 时**拒绝整个文件**。对单机桌面应用这是可辩护的；对一个在手机、平板、Mac 之间同步、且各自按自己节奏更新的文档，它意味着**最旧的设备会摧毁最新设备的工作**。

---

## 关键类型速览

```swift
PortraitDocument          // 一张照片的编辑，也是同步和预设的单位
  ├─ photo: PhotoReference      // 引用，不复制；相册 assetID 或相对路径
  ├─ ops: [RetouchOp]           // 修饰栈
  ├─ faces: [FaceAnalysis]?     // 缓存，可再生 —— 所以丢失它不是数据丢失
  └─ assets: [AssetRef]         // 手绘遮罩、光影图、液化偏移场

RetouchOp
  ├─ id: UUID                   // AI 寻址用
  ├─ kind: RetouchOpKind        // 21 种算子 + .unsupported
  ├─ isEnabled: Bool            // A/B 不删除
  └─ origin: OpOrigin           // .user / .preset / .ai(sessionID:)
                                //   ← "撤销 AI 这次做的全部" 靠它，不会碰用户自己的活
```

### 算子清单（按相位）

| 相位 | 算子 |
|---|---|
| geometry | `crop` `optics` |
| develop | `whiteBalance` `tone` `presence` `toneCurve` `colorMixer` `colorGrading` `detail` `calibration` |
| reshape | `reshape` |
| retouch | `skin` `blemish` `eyes` `teeth` |
| paint | `dodgeBurn` `localAdjustment` |
| finish | `grain` `vignette` |
| layout | `frame` `watermark` |

develop 拆成模块而不是一个大块，因为「只把调色同步到整组」是真实且高频的需求，也因为这让 AI 有一个精确的把手：`set_module_param(photo, "tone", "exposure", 0.3)`。

### 锚点

```swift
AnchoredPoint(space: .landmark(faceIndex: 0, landmark: .cheekLeft), value: [0.08, -0.03])
```

编码后长这样——模型能读懂，人也能读懂：

```json
{ "space": { "landmark": { "faceIndex": 0, "landmark": "cheekLeft" } }, "value": [0.08, -0.03] }
```

`Space` 三种：`.image`（整图归一化）、`.face(index:)`（人脸框归一化）、`.landmark(faceIndex:landmark:)`（**AI 应该用这个**——它在重新检测后稳定、对裁剪鲁棒、而且是模型从预览图就能推理的东西）。

---

## 两个必须现在就写的测试

`RetouchOpTests.swift` 里的前两组，不是补的覆盖率，是**规则本身的守卫**：

1. **前向兼容往返** —— `allKinds` 是唯一一份算子清单。新增一个 case，三个测试会失败，直到它：能往返、声明了相位、声明了手机能不能编辑。手写的编解码开关和产品元数据表正是最容易悄悄过期的东西。
2. **相位排序稳定** —— 如果它不再稳定，同一个文档在两台机器上会渲染出两个样子。那正是让非破坏编辑不可信的失败模式。

---

## 渲染契约——从 Compositor 学到的最重要一课

```swift
protocol RetouchRenderer {
    func renderStep(_ kind: RetouchOpKind, input: CGImage, context: RenderContext) throws -> CGImage
    func renderStack(_ document: PortraitDocument, input: CGImage, context: RenderContext) throws -> CGImage
    var tolerance: Int { get }
}
```

- `renderStep` 是**定义**：一个算子、一张图、纯函数。
- `renderStack` 是**生产路径**：可以融合算子（比如把 develop 的所有 LUT 合成一趟），但**必须等于把 `renderStep` 折叠一遍**。

Compositor 里有两套完整合成器（Core Graphics 一套、Core Image 一套），靠注释和人工纪律保持同步——那是它最大的技术债，根源就是**没有定义哪一套是权威的**。

这里定义了：`renderStep` 权威，融合是优化，**允许优化存在的前提是那个一致性测试**。第一天就写它，别等第一次发散之后。

---

## 验证方式

```sh
swift test
swift build --triple arm64-apple-ios18.0 \
  --sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  --scratch-path /tmp/portrait-ios-build
```

CI 已加入包测试及 iOS 编译。受限沙箱的替代验证方式见 `AGENTS.md`。

## 已实现：skin 与渲染契约

`RetouchKit.SkinRenderer` 实现 `skin` 的两版算法；新文档用 `processVersion = 2`，
旧版和缺失版本字段的文档继续用 1。整栈绑定文档版本，单步通过 `RenderContext`
接收版本。两个版本的输出有固定回归指纹，整栈与独立逐步折叠的像素差为 0。

支持显式皮肤遮罩、纹理保留、透明度、遮罩扩张和预览半径缩放。
非零 `blemishStrength` 明确报错。`PortraitRenderer` 已补齐 `tone` / `presence` / 点 `toneCurve` / 相对 `whiteBalance`；`PortraitAnalysis` 提供 Vision 关键点与保守皮肤遮罩。实片预览、MCP 与限制见 [原型说明](PROTOTYPE.md)。

---

## 还没做、但下一步该做的

- **进一步实片验证**：已用一张真实人像验证自动覆盖、三个磨皮候选和 MCP；仍需多肤色/光照/角度样本、祛瑕疵、完整皮肤分割与大图性能。
- **原生界面与客户端接入**：三个工具的进程内处理及 stdio 宿主已实现，事务测试模拟了确认；真实人工确认 UI、原 App 接入和 HTTP 尚未实现。
- **`SKILL-portrait-retouch.md`**：已加入首张实片的初步校准；需要人的偏好反馈和更多样本，不能泛化单张照片的阈值。
