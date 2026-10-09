# 迭代任务书

> 由**复核方 AI** 下达，交给**实现方 AI** 执行。用户会验收。
>
> **开工前先读 [`SYNC.md`](SYNC.md)** —— 在「正在做」登记你要接的任务编号，收工前移走。
> 每条任务都**独立可交付**：做完一条、测试通过、push，再接下一条。**不要并行做两条。**

---

## 零、每条任务都必须满足的完成定义

不满足其中**任何一条**，这条任务就不算完成：

1. `swift test` **和** `swift test -c release` 全过（当前基线 **45 项**）
2. `swift build --triple arm64-apple-ios18.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"` 仍能编译
3. `Sources/PortraitCore`、`PortraitAnalysis`、`RetouchKit` 里**没有** `import AppKit/UIKit`
4. 如果改了渲染：**既有的字节指纹测试仍然通过**（`SkinRendererTests`）——除非该任务明确要求 bump `processVersion`
5. 新增行为有测试；**测试名说清它守的是什么**
6. `SYNC.md`「刚完成」里写清 commit 哈希 + 一句话；`STATUS.md` 同步更新
7. 注释解释**为什么**，不解释**是什么**（这个包的注释密度是故意的）

**五条不可妥协的规则**（见 `PortraitFoundation/AGENTS.md`）在每条任务里都适用，尤其：
算子描述意图、栈按相位排序、区域必须用 `AnchoredPoint`、可创作性≠可渲染性、未知算子必须存活。

---

## 〇·三、⭐ 最终形态（2026-10-09，**优先于以下全部**）

**用户原话：「让最强的 AI 看我的照片，然后直接通过 MCP 操作修改我的照片。」**
**且：桌面端和 iPad 都没有笔 → 人审阅、AI 操作。** 设计见 [`AI-RETOUCH-LOOP.md`](AI-RETOUCH-LOOP.md)。

**现有三个工具形状是对的；缺的是「AI 能看清」。**

**新队列（插到最前）：**

| # | 任务 | 为什么 |
|---|---|---|
| **T14** | **`inspect` 工具**——1:1 皮肤裁切 / 人脸特写 / 整图 | ⭐ **AI 现在最多看 2048 px，毛孔级别的事它全看不见** |
| **T15** | **`measure` 工具**——纹理能量／改动像素／零覆盖改动 | 数字已在算，只是没暴露；成本极低 |
| **T11d** | **`capabilities` 工具**（从渲染器派生，替代硬编码） | 优先级提高——AI 靠它发现能力 |
| **T16** | **`compare` 工具**（前后／差值） | `ImageComparison.swift` 已有实现 |

**并行的两条不变、而且更重要**：

- **T13（明暗）／T4（斑点渲染）**——**没有笔，AI 是唯一能生成光影图和修补的手段**
- **`SKILL-portrait-retouch.md` 校准**——**它是 AI 唯一的审美依据**，从收尾工作提升为核心工作

---

## 〇·四、⚠️ 架构决策（2026-10-09，**优先于目标修正和旧派工**）

**见 [`ARCHITECTURE.md`](ARCHITECTURE.md) 与 `SYNC.md` 第〇·七节。**

**三台机器**：Windows（RTX 3090 / 96 GB / 照片库）跑分析；Mac 便携编辑；iPad 用笔本地渲染。
**文档（栈+资源）是唯一真相，分析结果存进文档，其他机器只读不算。**

**对任务书的两条硬改动：**

| | 改动 |
|---|---|
| **T10** | 选型从 **MLX 改为 ONNX Runtime + CUDA**（MLX 是 Apple Silicon 专属，Windows 跑不了）。优先级可降——**3090 上分析是亚秒级**，不再是长任务 |
| **新：跨平台分析出口** | `FaceAnalyzer` 现在**硬依赖 Apple Vision**。要抽出协议 + 一条 ONNX 实现，否则 Windows 上没有人脸检测 |

**新增且优先级最高的三件（都不在旧队列里）：**

1. **Windows 磁盘**（阻塞所有安装：D: 97%、F: 97%、pagefile 在 F:）
2. **验证 iPad 笔压通路**（Parsec / Sunshine+Moonlight，**零开发**，但决定 A/B 路线）
3. **文档同步**（Mac ↔ Windows，SMB 已通、延迟 3.2 ms，可能不需要写代码）

---

## 〇·五、⚠️ 目标修正（2026-10-07，来自用户，**优先于下面的旧派工叙述**）

用户指出：**目标是"最佳的皮肤质感"，不是祛痘。** 检索全文见
[`SKIN-QUALITY-RESEARCH.md`](SKIN-QUALITY-RESEARCH.md)。

**四条通道，全部有现成算子，缺的是实现与分析：**

| 通道 | 算子 | 状态 | 任务 |
|---|---|---|---|
| ① 纹理 | `skin` | ✅ 已实现、指纹锁定 | — |
| ② **明暗** | `dodgeBurn` | 🔴 渲染未实现 | **T13（新）** |
| ③ 颜色 | `localAdjustment` | 🔴 渲染未实现 | T14（暂缓，需先定与 tone 的边界） |
| ④ 斑点 | `.blemish` | 🟡 检测已做（T3），渲染未做 | T4 |

**顺序改成：②（T13）→ ④（T4）→ ③（T14）**，因为修图师是**先统一大面、再修局部**；
先点痘再整体压平会把刚修的功夫抹掉。

**② 的关键约束（来自检索）**：照 `retouch-dodge-burn-onnx` 的范式——
**分析产出一张可保存的灰色光影图，三端用确定性合成渲染**，而不是让模型直接改像素。
**先用确定性方法产图**（启发式/CLAHE/引导滤波），不够用再考虑模型。

---

## 一、任务的优先级与依赖

```
T1 起窗 ──┐
          ├─→ （用户能顺手打开 UI 试）
T2 并发根因 ┘

T3 斑点检测 ──→ T4 .blemish 渲染 ──→ T5 skin.blemishStrength
                                  └─→ （MCP 放开 const 0）

T6 遮罩覆盖（脖子/胸口/耳朵）      ← 独立
T7 性别化强度（只做管道）          ← 独立
```

**顺序建议：T1 → T2 → T8 → `T12` → T3 → T4 → T5 → T10 → T11 → T6 → T7。**
（**T12 已从 T11 抽出并插到最前**——坐标系是正确性问题，几行就能修完）
（T9 降级为备用；用户已授权走 T10 的质量优先路线）
T1、T2 都很小，先清掉，让用户马上能试用 UI。T3–T5 是一条链，是**当前最大的能力缺口**。

---

## T1 · 让 `swift run portrait-mac` 出窗口

**优先级** P0　**规模** 极小

**现象（已实测，不是推测）**

| 运行方式 | Accessibility 查到的窗口数 |
|---|---|
| 裸可执行文件 `.build/.../portrait-mac` | **0** |
| 同一二进制放进带 `Info.plist` 的 `.app` bundle | **1** |

`PortraitAppDelegate` 只实现了 `applicationShouldTerminate`，从未设置激活策略。
SwiftPM 产出的是裸 Mach-O，没有 bundle 身份，于是 SwiftUI 的 `Window` 场景不建窗口。

**影响**：任何人照直觉跑 `swift run portrait-mac` 都会以为程序坏了。

**改哪里**：`Sources/PortraitMac/PortraitMac.swift` 的 `PortraitAppDelegate`

**验收标准**
- [ ] `swift run -c release portrait-mac` 启动后，`osascript` 能查到 **≥1 个窗口**，标题为「人像修图 · 原型」
- [ ] 放进 `.app` bundle 运行时行为不变（仍能起窗）
- [ ] 关闭窗口时的退出确认（`applicationShouldTerminate`）仍然工作
- [ ] 在 `SYNC.md` 记录实测的窗口数

**明确不做**：不改窗口内容、不改 SwiftUI 视图结构、不引入打包脚本（那是另一个决定）

---

## T2 · 根治 MCP 测试套件的并发等待

**优先级** P0　**规模** 小

**现象**：你们在 `84d87bf` 记录里写了「并发 MCP suite 等待停滞，顺序执行后通过，**根因待独立复核**」，
并把 `MCPTests` 标成了 `.serialized`。

**为什么必须做**：用串行掩盖挂起，是把一个真 bug 变成定时炸弹。并发路径是真实的
（MCP host 和原生 UI 都会并发调 `PortraitSession`），测试里藏起来的挂起在生产里会变成卡死。

**先查这些方向**（`Sources/PortraitMCP/PortraitSession.swift`）
- `PortraitSession` / `MCPServer` 是不是 `@MainActor`？测试是否在跨 actor 等待时形成环？
- 预览票据「最多保留 4 张」——并发测试是否把票据池耗尽，导致后续 `set_stack` 拿不到票？
- 是否有 `await` 在持有某个锁/actor 隔离期间再次进入同一隔离域？

**验收标准**
- [ ] **写清根因**，能指到具体代码行。如果查不出，如实写「未定位」并说明已排除哪些假设——**不要编一个理由**
- [ ] 如果是票据耗尽：给出正确的测试隔离方式，并评估能否**去掉 `.serialized`**。能去掉就去掉
- [ ] 如果确实必须保留串行，注释里写清**为什么**，不能只留一个标记
- [ ] 测试数量不能减少

**明确不做**：不要用「加超时」「加重试」了事；那只是把挂起换成失败

---

## T12 · 补坐标系说明与范围校验 ⚡ **插队，先做这个**

**优先级** P0　**规模** 极小（几行 + 一条测试）　**依赖** 无
**由复核方在通读 `photoshop-mcp` 时发现**，详见 `PortraitFoundation/MCP-TOOLS.md` 尾部对照复审。

### 问题

`AnchoredPoint` 的三种 space **全部是归一化 0–1**：

```swift
case image                          // Normalized 0–1 across the whole image
case face(index: Int)               // Normalized 0–1 across a detected face's bounding box
case landmark(faceIndex:landmark:)  // face-width fractions
```

**但 `MCPServer.swift` 的 `initialize` instructions 里出现了两次 "pixel"**
（来自 `Source dimensions: \(w)×\(h)`），**却一个字都没提归一化**。

> **agent 会读到「尺寸 6240×4160」，然后合理地传 `{"value":[3000,2000]}`。**

对照 `photoshop-mcp`：它有专门的 Units 一节，明确写"全部是像素，
**server 会在每个脚本周围强制像素单位，不要换算成英寸/厘米/百分比**"。
**它们的单位是像素并明说了；我们的单位不是像素，却什么都没说。**

### 为什么插队

这不是文档欠缺，是**正确性问题**：agent 会传错单位，而结果**可能是静默错误的**
（取决于 `AnchoredPoint` 有没有范围校验——**你去确认**）。几行就能修，不值得排在 T3 后面。

### 要做

- [ ] **先查清**：`AnchoredPoint` 的值有没有 0–1 范围校验？传 `[3000,2000]` 会被拒绝，
      还是**静默**进到渲染里？
- [ ] `instructions` 里明确写：**坐标为 0–1 归一化**，并说明三种 space 各自的参照物
      （全图 / 人脸框 / landmark 的人脸宽度分数）
- [ ] 若没有范围校验：**加上**（拒绝越界），或明确文档化为什么宽松
      —— 参考 `PortraitFoundation/AGENTS.md`「校验要宽松，不要严苛」：
      **问自己"这个失败会让一份合法文档打不开吗？"** 归一化坐标是格式约定，越界不合法，**该拒绝**
- [ ] 加测试：越界坐标被拒绝（或记录为已知宽松点 + 理由）
- [ ] `SYNC.md` 记录实测：**实际传一次像素坐标，贴出发生了什么**

**明确不做**：不改 `AnchoredPoint` 的格式（那是文件格式，已冻结）；不做 11b–11e（那是 T11）

---

## T3 · 斑点检测

**优先级** P1　**规模** 中　**依赖** 无

**为什么**：两张实片（`0229_95_1.jpg`、`20261005.jpg`）里，皮肤上的红点在**最强档下依然可见**。
磨皮只解决"纹理"，不解决"斑点"。而 `blemishFraction` 目前是**占位符**、
`blemishDetectionAvailable` 是 `false`，`PROTOTYPE.md` 也写明了这一点。

**这是 `SkinParams.blemishStrength` 和 `.blemish` 算子共同的缺失前置。**

**⚠️ 动手前先读：为什么这里**不要**用生成式模型**（复核方调研 2026-10-06）

开源生态里祛瑕疵有两条路，**对你们的架构，只有一条是通的**：

| 路线 | 代表 | 问题 |
|---|---|---|
| **生成式修补** | [IOPaint](https://github.com/Sanster/IOPaint) / LaMa（**Apache 2.0**，支持 Apple Silicon，同作者已出 macOS+iOS 的 OptiClean） | 需要**模型**→ 同一文档在 Mac 与 iPhone 上**渲染不一致**，**违反规则 4**；且破坏字节指纹 |
| **确定性克隆/修补** | PS 的污点修复、GIMP 的 resynthesizer（**GPL，许可有传染性，不能链进非 GPL 应用**） | 算法要自己实现，但**无模型、逐位可复现、三端一致** |

**结论：T3 用确定性算法。** 判据是一条通用规则：

> **模型只用在「输出可以被保存」的地方（分析、遮罩、检测结果）；
> 输出必须三端逐位一致的地方（渲染），只用确定性算法。**

这条规则也解释了为什么 SAM3 那条路必须先解决"遮罩存哪"（T10 前置）——
因为**分析结果存下来之后**，iPhone 就不需要再跑模型，只负责渲染。

**所以**：检测（T3）与修补（T4）都走确定性路线。可以用 PatchMatch / 纹理合成的思路，
但**必须自己实现或用宽松许可的实现**（MIT / Apache-2.0 / BSD），**不要引入 GPL 代码**。

另外：LaMa/IOPaint 只解决「填什么」，**不解决「哪里是瑕疵」**——
检测仍然是 T3 的核心工作，那部分没有现成的可抄。

**改哪里**：`Sources/PortraitAnalysis/`（检测）＋ 填充 `FaceAnalysis.skinTone.blemishFraction`

**⚠️ 最重要的约束：宁可漏检，不可误删。**

`SKILL-portrait-retouch.md` 明确写着：**痣、雀斑、疤痕、皱纹往往是这个人的特征，除非被明确要求，不删。**
所以检测器的目标不是"找出所有暗点"，而是**只找出那些几乎肯定是暂时性瑕疵的**。
误删一颗痣，比漏掉十个痘更严重。

建议的判据（自己验证，不要照抄）：局部比周围皮肤**暗且红**、尺度在 2–20 原始像素、
**圆形**、**边界渐变**。痣通常更暗更饱和、边界更锐利——这正是要利用的差异。

**验收标准**
- [ ] `blemishFraction` 不再恒为 0，`blemishDetectionAvailable` 为 `true`
- [ ] **在两张实片上出可视化**：标出检测到的斑点位置，人工看一眼有没有把痣/雀斑吃进去
- [ ] 新增测试至少覆盖：① 一颗典型痘被检出；② **一颗痣不被检出**；③ 平滑皮肤误检率极低
- [ ] 检测是确定性的（同一输入同一输出）
- [ ] 检测不越出皮肤遮罩

**明确不做**：不实现修复（那是 T4）；不改磨皮算法；不引入神经网络分割

---

## T4 · `.blemish` 算子的渲染

**优先级** P1　**规模** 中偏大　**依赖** T3

**为什么**：`RetouchOpKind.blemish(BlemishParams)` 已经在数据模型里定义完整
（`Spot` 带 `at: AnchoredPoint`、可选 `source`、`Origin` 分 manual/detected/agent，
还有 `detectionThreshold` / `radius` / `hardness` / `opacity` 的校验），
但 `PortraitRenderer.renderStep` **没有实现它**，会抛 `unsupportedOperation`。

**这是"点掉一颗痘"这个动作本身。**

**改哪里**：`Sources/RetouchKit/PortraitRenderer.swift`

**要点**
- `source == nil` 时**引擎自己挑源**：优先在同一人的皮肤附近找一块，**这是"看不出来"的关键**
- `origin == .agent` 的 spot 按模型注释**必须**是 landmark 锚定的（见 `BlemishParams.Spot` 的注释）
- 遮罩语义要与 `skin` 一致：不能把修复带进眼睛、眉毛、嘴唇
- 保持 `renderStep` 是定义、`renderStack` 折叠它——**不许为了性能做旁路**，除非同时给了容差 0 的一致性测试

**验收标准**
- [ ] `renderStep(.blemish(...))` 不再抛错
- [ ] 新增测试：① 单点修复后该点在数值上接近周围皮肤；② **遮罩外零改动**；③ 栈折叠与逐步一致（容差 0）；④ 空 spot 列表是恒等变换
- [ ] 在 `20261005.jpg` 上出前后对比图，人工看修复处**是否留下可见痕迹**
- [ ] `skin` 的既有指纹不变

**明确不做**：不改 `skin`；不做液化/眼牙；不实现 `detectionThreshold` 的自动检测路径（T3 已负责检测，二者不重复）

---

## T5 · `skin.blemishStrength` 自动通道

**优先级** P2　**规模** 小　**依赖** T3（渲染复用 T4）

**为什么**：`SkinParams.blemishStrength` 已存在（0...1，默认 0），
注释说是"在检测出的斑点上叠加的额外局部平滑"。但 `SkinRenderer` 目前对非零值**直接抛错**，
且 `MCPServer` 的 schema 把它钉成了 `"const": .int(0)`。

**不需要 bump `processVersion`** —— 因为现在非零值直接抛错，
**不存在任何已保存的文档会走这条路径**，实现它不会改变任何现有渲染结果。
（动手前自己再确认一遍这个推理。）

**改哪里**：`Sources/RetouchKit/SkinRenderer.swift`、`Sources/PortraitMCP/MCPServer.swift`、
`Sources/PortraitAnalysis/` 的遮罩生成

**验收标准**
- [ ] `blemishStrength > 0` 不再抛错，且**效果随强度单调增强**
- [ ] **`blemishStrength == 0` 时逐位不变**（既有指纹测试必须仍然通过）——这是最重要的那条
- [ ] 同时放开 MCP schema 的 `const 0`，改为 `0...1` 并给出范围提示
- [ ] 新增测试覆盖：0 是恒等；非零只改检测到的斑点邻域；遮罩外零改动
- [ ] 在实片上出 `0` vs 中档 vs 高档的对比图

**明确不做**：不把 `blemishStrength` 并入 `strength`（它们是两个意图）

---

## T6 · 遮罩覆盖扩到脖子 / 胸口 / 耳朵

**优先级** P2　**规模** 中　**依赖** 无

**现象**：两张实片的 `mask-overlay.png` 里，**脖子、胸口、耳朵全部在覆盖之外**。
`20261005.jpg` 是双人场景，两人都是如此。

**为什么**：脖子与面部的肤色衔接是修图常规工作。修图师不会接受"脸磨了、脖子没磨"。

**⚠️ 约束：必须仍然保守。** 脸部以外没有关键点可依赖，只能靠色度 + 从人脸尺寸几何外推。
**把衣物/背景误当成皮肤的代价，远大于漏掉一块脖子。**

**已有的研究线索（见 `SYNC.md` 第三·五节，不要重跑模型）**

上游做过一轮分割模型调研，结论对这条任务直接有用：

- **不要把神经网络遮罩直接替换现有启发式**——四个模型都把夜拍的贴钻判成皮肤。
- 但学习模型有两个真实优势，可作为**改进方向**而不是替换：
  1. **额头/发际线覆盖比现有启发式更连续**（现有几何法在这里有明显缺口）
  2. **能把眼镜单独分类**（现有方法只能整体几何排除，会连镜片后的皮肤一起排掉）
- 无饰物对照脸的 51 个亮点候选**包含自然反光**，所以"亮点"不能当作扩展依据。

**如果这条任务要靠神经网络才能做好，那是一个需要用户拍板的架构决策**，先停下来问，
不要自行引入（这也是本节「明确不做」的含义）。

**改哪里**：`Sources/PortraitAnalysis/FaceAnalyzer.swift`

**验收标准**
- [ ] 在两张实片上出叠加图，脖子/胸口/耳朵确有覆盖
- [ ] **衣物、背景、头发的覆盖率没有上升**（给出量化对比，不能只看图）
- [ ] `protectedPixelsChanged` 仍然为 0
- [ ] 既有测试全过；新增测试覆盖"靠近肤色但属于衣物"的区域**不被选中**
- [ ] `detectorVersion` 字符串要更新（格式见现有的 `vision-rect3-landmarks3-chroma1`）

**明确不做**：不引入神经网络分割（那是一个需要用户拍板的架构决策）；不改脸部内的遮罩行为

---

## T7 · 性别化强度（只做管道，**不做检测**）

**优先级** P3　**规模** 小　**依赖** 无

**用户原话**：「应该分性别的（这个可以后面再实现）」。

**⚠️ 关键判断：不要试图自动检测性别。** Vision 不做这件事，猜错的代价（把男性磨成女性或反过来）
比不猜高得多。这条任务只做**让偏好能被表达和覆盖**的管道。

**改哪里**：`SKILL-portrait-retouch.md`、以及候选/默认值的取值路径

**当前已知**（`SKILL` 已部分记录）
- 男性下限约 **`texturePreservation` 0.30**（用户在 `20261005.jpg` 上选定，`strength` 0.65）
- **女性下限未测定**——`0229_95_1.jpg` 是浓妆，皮肤本身已无纹理，**不能用来定这条**

**验收标准**
- [ ] `SKILL` 里写清「女性未测定」，**不要编一个值**
- [ ] 提供一个**用户可覆盖**的入口（一个显式的偏好设置或参数），而不是硬编码两张表
- [ ] 文档写清「当前证据只有男性一个数据点，且来自单张照片」

**明确不做**：不写性别分类器；不假设可以从图像推断

---

## T8 · 向 App 传文件会导致它退出

**优先级** P1　**规模** 极小　**依赖** 无　**建议排在 T3 之前**（只要几行，但它毁第一印象）

**现象（复核方实测复现，两次）**

App 正在运行时，执行 `open -a PortraitMac.app 某张照片.jpg`，**App 立刻退出**。

复现步骤：
1. `open ~/Applications/PortraitMac.app`，确认窗口在
2. `open -a ~/Applications/PortraitMac.app /Users/xiaoman/Pictures/20261005.jpg`
3. `pgrep -f PortraitMac.app` → **空**（已退出）

**没有崩溃日志**，是干净退出。已排除是打包问题：给 `Info.plist` 加上
`CFBundleDocumentTypes`（`public.image`）后**仍然退出**，所以与 bundle 声明无关。

**影响**：这是用户最容易尝试的操作之一——**把照片拖到 App 图标上**，或者右键「打开方式 → 人像修图」。
两种情况都会让程序直接关掉，而不是打开那张照片。

**原因（读代码得出）**：`PortraitMac.swift` 里**没有实现** `application(_:open:)`，
收到 `odoc` 事件后进程终止。

**改哪里**：`Sources/PortraitMac/PortraitMac.swift` 的 `PortraitAppDelegate`

**验收标准**
- [ ] App 运行时 `open -a` 传一张照片 → **App 不退出**，并且**那张照片被载入**（标题/面板不再是「尚未打开照片」）
- [ ] 拖拽到 App 图标、右键「打开方式」同样生效（至少验证前者）
- [ ] 传一个非图片文件 → **不退出**，给出可读的提示或忽略
- [ ] 若当前有未保存改动，沿用既有退出确认逻辑，**不能静默丢弃**
- [ ] 用 AX 探针或窗口标题证明照片**确实载入了**，而不是只是没退出
- [ ] `SYNC.md` 记录实测结果

**明确不做**：不改 `NSOpenPanel` 的既有流程；不引入文档类型/多窗口架构

---

## T9 · 装饰物保护（先走无模型方案）

**优先级** P1　**规模** 中　**依赖** 无　**建议排在 T3 之后**

**问题（复核方实测，用户可见）**

用户自己的 `0.65/0.30` 下，`20261005.jpg` 之外的**浓妆夜拍**脸上，**泪痕亮片被抹成一片虚糊**。

证据（`assets/face-parsing-trial/mlx-protection-sam3-v2/decorated-face-1/`）：
`baseline-standard.png` 与 `optimized-standard.png` 相差 **72,561 像素（3.36%）**，
最大通道差 **49**，其中 4,834 个像素差 > 8，**集中在亮片与泪痕上**。放大目视：baseline 糊，optimized 颗粒分明。

**根因（已核实）**：**App 里没有任何装饰物保护逻辑**。
`grep -rniE 'glitter|rhinestone|pearl|bright|specular|decoration' Sources/` 在渲染代码里零命中。

**⚠️ 先试便宜的路，不要直接上模型**

上游已经写了**不需要任何模型**的亮点检测，在 `scripts/face-parsing/protection.py`：
局部亮、低饱和、相对 ~0.7% 脸宽的高斯有局部对比度，再按连通域面积/峰值筛选。
**先把它接进 App。** SAM3 每脸 24–30 秒且带许可问题，只有在 T9 不达标时才考虑（另开 T10）。

**改哪里**：`Sources/PortraitAnalysis/FaceAnalyzer.swift`（遮罩生成）为主，
必要时在 `RetouchKit` 里加保护通道。**不要改 `processVersion` 语义**——
这是**遮罩生成**的改进，不是算子语义变更；但要确认这一点，若改变已有文档渲染则必须 bump。

**验收标准**
- [ ] 在同一张浓妆实片、**同一强度 0.65/0.30** 下，泪痕亮片**目视不再发糊**
- [ ] **量化**：与现有 baseline 的差异集中在装饰物上，且**普通皮肤区域没有出现新的保护空洞**
      （给出普通脸的前后对比，证明不会误伤正常磨皮）
- [ ] 与 SAM3 的 `optimized-mask` 对比，报告**覆盖率差距**（作为参照上界，不要求追平）
- [ ] 既有 49 项测试全过；**skin 的 v1/v2 字节指纹必须仍然通过**（`blemishStrength`/遮罩默认路径不变时）
- [ ] 遮罩外零改动；`protectedPixelsChanged` 为 0
- [ ] 在 `20261005.jpg`（无装饰）上验证**没有引入新的保护空洞**
- [ ] 处理耗时增量可接受（相对现有分析），并在 `SYNC.md` 记录实测

**明确不做**：不引入 SAM3/MLX/任何模型权重（那是 T10）；不声称识别精度；不改保存格式

---

## T10 · 接入选定的分割与装饰保护

**优先级** P1　**规模** 大　**依赖** 无（选型已由 `scripts/face-parsing/DECISION.md` 定案）

**背景**：用户已授权**质量优先路线**，取代"先做 T9 才考虑 SAM3"的前置条件。
选定方案见 `scripts/face-parsing/DECISION.md`：
**FaRL 皮肤分割 + SAM3 BF16 装饰保护 + 自动局部 ROI + 保守确认 + 核心锁定/距离羽化。**

> T9（无模型的亮点规则）**不删除**，降级为**备用/降级候选**。
> 但**不允许静默降级后仍声称语义保护**——降级必须显式、可见。

### ⚠️ 动手前必须先决定：**遮罩要不要进文档**

这是本任务最大的架构问题，**必须先有结论再写代码**。

现状：遮罩**不在文档里**，而是独立 sidecar（`<document>.analysis.json`），
按 `sourceHash` 键控、`AnalysisCache.version == 1`、**缓存缺失即重新生成**
（`PortraitSession.swift:91`、`:258`）。

问题：
- SAM3 BF16 峰值约 **3.87GB**，**iPhone 跑不了**
- 于是同一张照片：Mac 用 SAM3 生成遮罩，iPhone 重新生成时只能用启发式 → **遮罩不同 → 渲染不同**
- 这**直接违反规则 4**（"iPhone 必须能导出 iPad 上做的片子"）

**可选方向**（需要用户拍板，不要自行决定）：
1. **把"已批准的最终遮罩"存进文档**（或随文档同步的独立文件）——重开、换设备都不重算。
   代价：文档变大；需要文件格式版本号。
2. 接受设备本地遮罩，并在产品上明确"iPhone 只能渲染 Mac 处理过的成品，不能再编辑遮罩"。
   **这需要显式记录为架构决策**，不是加个 `default:` 能糊过去的。

`DECISION.md` 第 41 行倾向方向 1（"保存已批准的最终遮罩与来源，重开不依赖重新检测"），
但它**没有说明存在哪、是否随文档同步**。**先把这个写清楚。**

### 其余实现要求（来自 `DECISION.md` 41–43 行）

- 可取消的分析入口（对照 T2 的教训：**阻塞框架调用不能跑在协作线程池上**）
- 会话缓存按 **源哈希 / 区域 / 模型 revision / 提示与遮罩配置** 隔离；调磨皮参数**复用**分析
- **旧编辑不得因模型升级而改变渲染**——已批准遮罩一旦保存，永不重算
- 预览、批准、原尺寸检查、导出**必须使用同一份最终遮罩**
- 提供**可查看并修正保护区域的入口**（用户能手工补/删保护）

**验收标准**
- [ ] 既有 49 项测试全过；iOS 能编译；核心 target 无 AppKit/UIKit
- [ ] `skin` 的 v1/v2 字节指纹仍通过（未启用新遮罩时逐位不变）
- [ ] 在同一张浓妆实片、**同一强度 0.65/0.30** 下，亮片**目视不再发糊**（对照 `optimized-standard.png`）
- [ ] **普通脸不引入新的保护空洞**——在无装饰实片上与 baseline 逐像素比对
- [ ] 同时给出：原图 / 最终图 / 实际像素差 / 保护遮罩 四张图
- [ ] 速度**分开报告**：首次分析耗时、缓存后渲染耗时（重复测量，`-c release`）
- [ ] 遮罩来源（模型 revision、权重 SHA、提示配置）随遮罩一起保存
- [ ] **不声称**准确率/召回率；亮片漏检与邻近皮肤过保护作为已知局限写入文档
- [ ] `SYNC.md` 记录实测数字与复现命令

**明确不做**：不继续扩大模型比较（`DECISION.md` 已收敛）；不改 `processVersion` 语义
（这是遮罩生成的改进，不是算子语义变更——但若导致已保存文档渲染变化，必须 bump）

---

## T11 · 按 `photoshop-mcp` 的对照改进 MCP 工具面

**优先级** P2　**规模** 中　**依赖** 无
**依据**：`PortraitFoundation/MCP-TOOLS.md` 末尾的对照复审

参考对象 MIT 许可，**读设计，不要抄传输层**（它必须跨进程桥，我们不需要）。

### 11a. （已抽为 **T12**，插在队列最前，先做那个）

### 11b. 结构化错误信封

现在是 `{"isError": true, "content": [{"type":"text","text":"\(error)"}]}`——**只有一句话**。

改成：`{ ok: false, code, message, suggested_next_tool?, suggested_args? }`

- [ ] 定义错误码枚举（对照 `SkinRenderError` / `PortraitSessionError` / `PhotoIOError`）
- [ ] 每个码给出 `suggested_next_tool`（例：`session_id` 非法 → 重新调 `render_preview_with` 拿票据）
- [ ] 保留人类可读的 `message`（`84d87bf` 已经改好的那些句子不要丢）
- [ ] 新增测试断言错误响应里含 `code` 与 `suggested_next_tool`

### 11c. `instructions` 从一句话扩成契约

- [ ] 工作流契约（分析 → 预览 → 人确认 → `set_stack`）
- [ ] **坐标系与单位**（见 11a）
- [ ] 错误码表
- [ ] `render_preview_with` 的使用纪律：**每个主要步骤一次，不要每步都调**

### 11d. 能力清单不要硬编码

instructions 里写死了 "Only skin, tone, presence, whiteBalance and point toneCurve are implemented"，
**这会和 `PortraitRenderer` 的 switch 漂移**。

- [ ] 加一个 `get_capabilities` 工具，从 `PortraitRenderer` 实际支持的集合派生
- [ ] 或至少让这份清单只有一个来源

### 11e. 用 MCP `prompts` 暴露 `SKILL-portrait-retouch.md`

`photoshop-mcp` 有 **23 个 prompt**（`prompts/list` / `prompts/get`）。
我们**只用了 tools**，而 270 行的修图方法论现在是一个客户端得自己去找的文件。

- [ ] 把 SKILL 的关键流程做成 MCP prompts（例如"保守修一张人像"、"判断强度"）
- [ ] 保留 SKILL 作为唯一的文字来源，prompt 从它派生

**验收标准**
- [ ] 既有 52 项测试全过；新增覆盖 11a/11b 的断言
- [ ] iOS 编译通过；核心 target 无 AppKit/UIKit
- [ ] 用一个**独立客户端**（不要用仓库自带的脚本）实际走一遍：非法参数拿到 `code`、
      按 `suggested_next_tool` 自我修复成功、`prompts/list` 能列出内容
- [ ] `SYNC.md` 记录实测

**明确不做**：不引入跨进程桥；不改现有的票据/revision 事务（那比参考实现更强）

---

## T13 · 明暗通道：Dodge & Burn 的图与渲染 ⭐ **下一个**

**优先级** P1　**规模** 中偏大　**依赖** 无
**依据**：用户目标修正（见第〇·五节）与 [`SKIN-QUALITY-RESEARCH.md`](SKIN-QUALITY-RESEARCH.md)

### 为什么是这条

用户的原始目标是**最佳皮肤质感**，四条通道里 ① 已实现，**② 明暗是修图师工作流的第二步**，
而且**算子早就定义好了，只是渲染器没实现**。

修图师**先统一大面、再修局部**——先点痘再整体压平，会把刚修的功夫抹掉。所以 ② 排在 ④ 前面。

### ⚠️ 好消息：**格式问题已经有了答案，不要再重新设计**

`DodgeBurnParams` 已经完整定义：

```swift
public struct DodgeBurnParams: Codable, Sendable, Equatable {
    public enum Blend: String, Codable, Sendable {
        case softLight      // 50% grey on Soft Light — the classic, and the safest default
        case overlay
        case luminanceOnly  // Only L changes; hue and saturation are held. For skin, this is usually right.
    }
    public var map: UUID          // AssetRef id, kind == .signedLight16
    public var amount: Double = 1 // -2...2
    public var blend: Blend = .softLight
    public var contrast: Double = 0
}
```

**`map` 是 `AssetRef(kind: .signedLight16)`，而 `PortraitDocument.assets` 已经存在**
（`RetouchOp.swift:77`，注释明确写了 "painted dodge & burn maps"）。
校验也已经就位（`:950` 检查 asset 是否存在）。

**结论：光影图是【文档资源】，不是【可重新生成的分析缓存】。**
它天然随文档走，**所以 iPhone 能渲染 Mac 上做的光影**——规则 4 自动满足。

> 这条区分很重要，请记进 `AGENTS.md` 或 `MCP-TOOLS.md`：
> **可确定性重算的分析 → 缓存（sidecar）；不能重算或经人修改的 → 资源（进文档）。**
> T10 的 SAM3 遮罩属于后者（iPhone 跑不了 SAM3），**所以它也应该变成资源**。

### 要做三件事

**A. 分析：产出带符号光影图**（先确定性，**不要一上来找模型**）

- 输出一张 `signedLight16`：**正值 = dodge（提亮），负值 = burn（压暗）**，
  中性 = 0。模型 card 的范式是"**交还一张灰图，不是滤过的照片**"——
  我们照做，因为灰图**可保存、可人工改、可三端一致渲染**
- 先试确定性方法（局部明暗不均的平滑估计、CLAHE 风格的自适应、引导滤波），
  **只有在不够用时才考虑模型**，而且要记住模型会把图变成"不可在 iPhone 上重算的资源"
- **必须保护**：痣、雀斑、疤痕、亮片、妆容**不能进光影图**（它们是特征，不是"需要压平的起伏"）

**B. 渲染：实现 `.dodgeBurn`**

- `PortraitRenderer.renderStep` 里实现 `.dodgeBurn`，目前抛 `unsupportedOperation`
- 三种 `Blend` 语义要按注释实现，尤其 `luminanceOnly`（注释说"for skin, this is usually right"）
- `contrast` 在**应用前**曲线化光影图；`amount == 0` 必须是**恒等**

**C. 资源的读写**

- 让 `signedLight16` 能被写出/读入并存进文档
- 确认 **16 位精度**在往返后逐位保持（8 位不够做细腻的光影）

### 验收标准

- [ ] 全零光影图 → **恒等变换**（逐位不变）
- [ ] `amount == 0` → **恒等变换**
- [ ] 三种 `Blend` 产生**可区分且有文档依据**的结果；`luminanceOnly` **不改变色相/饱和度**
- [ ] `signedLight16` 往返**逐位一致**（16 位精度不丢）
- [ ] **`renderStack` 折叠 `.dodgeBurn` 与独立 `renderStep` 一致，容差 0**
- [ ] **不误伤特征**：在 `20261005.jpg` 上人工标注几个痣/雀斑/胡茬位置，
      断言它们在光影图里**接近中性**（这是唯一能自动抓住"把痣当暗斑压暗"的办法）
- [ ] **无光晕/接缝**：沿光影图边界取剖面，见过冲或台阶
- [ ] 既有 55 项测试全过；**`skin` 的 v1/v2 指纹不变**
- [ ] iOS 编译通过；核心 target 无 AppKit/UIKit
- [ ] 出**四联图**（原图 / 结果 / 差值 / 光影图），**给人看**——
      交接里说了"验收以实际成片为主，检测数量只是辅助指标"
- [ ] `SYNC.md` 记录实测与复现命令

**明确不做**：不改 `DodgeBurnParams` 的格式（已冻结）；不做 ③ 颜色通道（T14）；
不引入模型（除非 ② 的确定性方法被证明不够用，那要单独讨论）

---

## 二、暂不排期（需要先讨论）

| 事项 | 为什么先不做 |
|---|---|
| **iPad 客户端** | 用户明确要三端，但这是新平台的起步工作，需要先定共享哪些代码、UI 如何分工 |
| **iPhone 客户端** | 同 iPad，且用户说过可以省掉需要笔的功能 |
| **压感 / Apple Pencil** | 需要先有 iPad 端 |
| **`CompositorKit` 抽取** | 与新 App 的关系（复用 vs 重写像素引擎）尚未决定 |
| **液化 / 眼牙 / 光影** | 依赖顺序在祛瑕疵之后 |

---

## 二·五、值得一读的参考（不是任务）

| 项目 | 许可 | 为什么值得看 |
|---|---|---|
| [alisaitteke/photoshop-mcp](https://github.com/alisaitteke/photoshop-mcp) | **MIT** | 它**独立地**解出了和你们相同的问题：**状态感知**（`get_state` / `get_preview` / `get_capabilities`）、**recipe 工具**（把多步操作包成**单个撤销步骤**）、**结构化错误信封**（让 agent 知道下一步试什么）。**"recipe" 和你们的 `RetouchOp` 栈是同一个想法。** |
| [Sanster/IOPaint](https://github.com/Sanster/IOPaint) | 工具本身开源；模型各异 | 祛瑕疵的生成式路线。**但见 T3：模型会破坏三端一致的渲染**，所以只作参照，不作依赖 |

**关键区别，别照抄架构**：Photoshop MCP 必须跨进程桥（ExtendScript / UXP WebSocket）才能驱动 PS，
而**你们不需要**——因为 `RetouchOp` 是可序列化数据。`MCP-TOOLS.md` 里已经写明了这一点。
**读它的工具面设计，不要读它的传输层。**

---

## 三、给实现方的两条提醒

1. **不要在一条任务里顺手改别的。** 你上一轮把 MCP suite 改成 `.serialized` 时留了
   「根因待复核」，这是对的——**写清未解决的部分比假装解决了好**。请保持这个习惯。

2. **报告实测数字时要写清配置。** 我上一轮报过一个 Debug 数字当成真实性能（18.7 s vs 503 ms），
   被我自己纠正。`swift build` 默认是 `-Onone`。**报任何性能数字前先指定 `-c release`。**

---

## 四、验收方式

每条任务完成后，复核方会**独立**做这几件事（不是读你的总结）：

- 跑 `swift test` 与 `swift test -c release`
- 跑 iOS 编译
- 读你改的源码，确认没有旁路、没有 `default:` 糊弄
- **看输出的图**（对比图、遮罩叠加）
- 在真实照片上复跑一遍

所以：**报告里请附上可复现的命令和你自己的实测数字。**
