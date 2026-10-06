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

**顺序建议：T1 → T2 → T8 → T3 → T4 → T5 → T6 → T7。**
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

## T3 · 斑点检测

**优先级** P1　**规模** 中　**依赖** 无

**为什么**：两张实片（`0229_95_1.jpg`、`20261005.jpg`）里，皮肤上的红点在**最强档下依然可见**。
磨皮只解决"纹理"，不解决"斑点"。而 `blemishFraction` 目前是**占位符**、
`blemishDetectionAvailable` 是 `false`，`PROTOTYPE.md` 也写明了这一点。

**这是 `SkinParams.blemishStrength` 和 `.blemish` 算子共同的缺失前置。**

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

## 二、暂不排期（需要先讨论）

| 事项 | 为什么先不做 |
|---|---|
| **iPad 客户端** | 用户明确要三端，但这是新平台的起步工作，需要先定共享哪些代码、UI 如何分工 |
| **iPhone 客户端** | 同 iPad，且用户说过可以省掉需要笔的功能 |
| **压感 / Apple Pencil** | 需要先有 iPad 端 |
| **`CompositorKit` 抽取** | 与新 App 的关系（复用 vs 重写像素引擎）尚未决定 |
| **液化 / 眼牙 / 光影** | 依赖顺序在祛瑕疵之后 |

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
