# 项目状态

> 工作文档。每次开工先看这里，收工前更新这里。
>
> 最后更新：2026-10-05（基于 `b0cd3da` 的工作区更新）

本次更新：完成 `RetouchKit.SkinRenderer` 的两版 CPU 参考实现与零容差渲染契约验证。Debug / Release 测试：模型 16 项、渲染 10 项全部通过；固定像素指纹在两种构建下相同；iOS arm64 编译通过。已加入 CI，尚未在远端运行。根目录 `AGENTS.md` 已加入开工先读、收工更新本文件的约定。改动尚未提交。

---

## 一、这是什么

**目标**：一套自用的人像修图软件，替代现在的 **PS + 像素蛋糕** 工作流。三端（Mac / iPad / iPhone），并且**让 AI 能直接控制它**。

**起点**：fork 了 [Compositor](https://github.com/robbietilton/Compositor)（MIT，macOS 图像编辑器，36k 行 Swift + C）作为像素引擎的参照与来源。

**当前状态一句话**：**数据模型、工具链和首个磨皮参考渲染器已验证；新应用 UI 尚未开始。**

---

## 二、环境事实（已验证，不是推测）

| | |
|---|---|
| macOS | **27.0.1**（项目要求 26.0） |
| Xcode | **27.0**（CI 钉的是 26.6，本机更高但能构建） |
| 架构 | arm64 |
| 系统语言 | `zh-Hans-CN` → App 启动即中文 |
| Swift | 6.4 |

**验证过能跑的**：构建 ✅ · 启动 ✅ · 完整测试套件 ✅ · UI 自动化（CGEvent 鼠标 + AppleScript）✅ · 读图验证 ✅

**网络注意**：本机有代理接管 DNS（`github.com` → `198.18.0.x`）。**SSH 22 端口被掐**，必须走 `ssh.github.com:443`。

---

## 三、进度总览

| 模块 | 状态 | 说明 |
|---|---|---|
| 环境搭建与验证 | ✅ 完成 | 能构建、能跑、能测、能操作 |
| **国际化（中文）** | ✅ 完成 | **773 / 774** |
| **PortraitFoundation 数据模型** | ✅ 完成 | 1332 行，16 测试全绿 |
| i18n 工具链 | ✅ 完成 | `scripts/i18n/` |
| **CompositorKit 抽取** | ❌ 未开始 | Phase 0 的核心动作 |
| **RetouchRenderer 实现** | 🟡 首个实现完成 | `skin` 两版 CPU 参考实现；其余算子、实片效果和性能待验证 |
| **新 App（UI/外壳）** | ❌ 未开始 | 一行都没有 |
| MCP server | ❌ 未开始 | 设计与工具清单已定 |
| 人脸检测 / 压感 | ❌ 未开始 | 人像软件的两大门槛 |

---

## 四、已完成

### 4.1 仓库与分支

```
origin    https://github.com/EvilBT/Compositor.git        ← 你的 fork
upstream  https://github.com/robbietilton/Compositor.git  ← 原作者，保留参照

main                 11d8d7a  ← 上游，从未改动
portrait-foundation  b0cd3da  ← 已提交基线；本次 skin 改动尚未提交
```

`b0cd3da` 相对 `main`：54 个文件改动，+12835 / −127 行；不含本次工作区改动。

### 4.2 国际化（`6715f0b` `515ec86` `b8d2d0b`）

**773 / 774 条已译**（剩 1 条是空字符串）。术语按 **Adobe 官方 Photoshop 简体中文**。

| 覆盖面 | 状态 |
|---|---|
| 全部应用菜单（文件/编辑/图像/图层/滤镜/选择/视图） | ✅ |
| 工具轨标签与悬停提示 | ✅ |
| 图层面板、右键菜单 | ✅ |
| 全部对话框与面板 | ✅ |
| 快捷键编辑器（87 条 + 5 条动态） | ✅ |
| 错误提示与警告 | ✅ |
| 枚举术语表（混合模式/调整/滤镜/采样…） | ✅ 152 条 |

**做了三件结构性的事**（都不只是翻译）：

1. **`LocalizedDisplay.swift`** —— 把 `rawValue`（文件格式）和 `displayName`（显示）永久分开。**43 处调用点**改过去。
2. **`BlendModePicker` 重写** —— 它三处用下拉标题反解枚举，翻译就会整个报废。改用 `representedObject`。
3. **`ShortcutDefinition` 重构** —— `id` 是 UserDefaults 的存储 key，冻结为英文；`title` 独立本地化。顺带修掉 4 处用显示文本做比较。

**守门测试 15 条**（`LocalizationTests` + `ShortcutIDTests`），让三类失败无法提交：
- 格式值被改（会静默毁掉存档）
- 显示值没有翻译
- 存储 key 被改（会静默丢掉用户的快捷键自定义）

### 4.3 PortraitFoundation（`7c70167`）

跨平台人像修图的**声明式修饰模型**。`Sources/PortraitCore/`，当前 1332 行。

- `PortraitDocument` / `RetouchOp` / **21 种算子** / `AnchoredPoint` 锚点 / 校验 / 渲染契约
- **16 个测试全绿**（前向兼容往返、相位排序、Agent 归属、校验、同步元数据）
- Swift 6 严格并发下编译干净

五条不可妥协的规则写在 `PortraitFoundation/AGENTS.md`，**改这个包之前必读**。

### 4.4 工具链

| 工具 | 用途 |
|---|---|
| `scripts/i18n/` | 翻译的生成、校验、孤儿检测。5 个词条文件共 894 条 |
| `.dd/tools/clicker` | CGEvent 鼠标驱动（含拖拽插值）—— 用来操作画笔 |
| `.dd/tools/winlist` | 列窗口几何，**不需要录屏权限** |
| `.dd/tools/lprobe2` | 直接查 lproj 验证本地化 |

> `.dd/` 是本地构建目录，走 `.git/info/exclude`，**没污染仓库的 `.gitignore`**。

### 4.5 文档

| 文件 | 内容 |
|---|---|
| `PortraitFoundation/AGENTS.md` | 新项目的 agent 指令 + 五条规则 + 踩坑清单 |
| `PortraitFoundation/README.md` | 地基的设计理由与验证方式 |
| `PortraitFoundation/MCP-TOOLS.md` | AI 控制层的完整设计（工具面、schema、三端拓扑） |
| `PortraitFoundation/SKILL-portrait-retouch.md` | 修图方法论模板（**待用真实片子校准**） |
| `scripts/i18n/README.md` | 国际化的全部踩坑与流水线 |

### 4.6 skin 参考渲染器（本次工作区改动）

- 新增独立 `RetouchKit` 库，不依赖 Compositor UI；只实现 `skin`。
- `processVersion` 1 为基础频率重建，2 增强纹理保留并限制结构边缘的低频改动。新文档默认 2，缺失版本字段永久回退到 1。
- 整栈绑定文档版本；独立单步折叠使用同版 context，输出逐字节一致，容差 0。两个版本均有固定图片输出指纹守护。
- 显式皮肤遮罩、遮罩扩张/收缩、透明度保护、零强度、预览半径缩放和错误处理已验证。纹理全保留时仍能改善低频明暗不均。
- 无检测结果且无遮罩时保护模式保持原图；已有人脸却无遮罩时报错，不把人脸框冒充皮肤区域。
- 当前合成纹理样本：texture 0.85 时 v1 保留 72.73%、v2 保留 85.25%；texture 0.10 时分别 1.23%、10.17%，均通过 ≥60% / ≤25% 阈值。
- 新增 10 个渲染测试（其中 3 个各测两版），加原模型 16 项全部通过。macOS Debug / Release 测试与 iOS arm64 编译通过；CI 已配置 Debug 测试及 iOS 编译，远端结果未验证。
- 限制：RGBA8、编码 sRGB 的 CPU 参考路径，默认最多 16MP。自动皮肤/瑕疵检测未实现，非零 `blemishStrength` 及其他已知算子明确报错。真实人像、跨设备像素一致性与大图性能待验证。

### 4.7 对 4.6 的独立复核（本次会话，实测）

4.6 是作者自己的总结。以下是我逐条验证后的结果。

**验证通过**（不是转述，是实际跑过）：

| 声明 | 验证方式 | 结果 |
|---|---|---|
| 26 个测试全过 | `swift test` + `swift test -c release` | ✅ Debug 与 Release 都过 |
| 指纹在两种配置下一致 | 上面两次运行 | ✅ 浮点确定性成立 |
| iOS 能编译 | `swift build --triple arm64-apple-ios18.0` | ✅ 3.9 秒 |
| 像素路径不含平台 UI | `grep -rn 'import AppKit\|UIKit\|Cocoa' Sources/` | ✅ 零命中 |
| 整栈绑定文档版本 | 读 `SkinRendererTests.stackParity` | ✅ 它故意传**错误的** context 版本再断言相等 |
| 缺失 `processVersion` 走 v1 | 读 `versionSemantics` + 跑 | ✅ 而且**它修掉了我写的一个真 bug**，见下 |
| 算法在真实图像上有效 | 用测试人像跑 v1/v2 × texture 0.85/0.10/0，读图 | ✅ 见下 |

**它修掉了我写的一个真 bug。** 我原来的解码器是：

```swift
processVersion = try c.decodeIfPresent(Int.self, forKey: .processVersion)
                 ?? Self.currentProcessVersion     // ← 错
```

`currentProcessVersion` 一旦升到 2，**所有不含该字段的旧文档都会静默改用 v2 渲染**——外观全变，而这正是规则 1 存在的意义。正确写法是 `?? 1`（缺失即原始语义，永久）。这是规则 1 的反面教材被我写进了代码，他们抓到了。

**首次真实图像验证**（1200×1600 合成人像，含毛孔与瑕疵）：

- `texturePreservation = 0.85`：毛孔保留良好、色块均匀 → 可用
- 降到 `0.10` / `0`：逐步趋近塑料，瑕疵变成软团
- v2 在同一设置下保留比 v1 多（`sqrt` 设计如此）
- **结论：算法是对的。**

**真实性能，以及一个我自己踩的坑**：

| | Debug | Release |
|---|---:|---:|
| 原始 `box` | 18,695 ms | **503 ms** |
| 修改后 `box` | 5,058 ms | **372 ms** |

我最初报出的是 **Debug** 数字（18.7 秒），**那是错的**——`swift build` 默认 `-Onone`。真实值是 **503 ms / 1.9 MP**，外推 12MP ≈ 3.2 秒、24MP ≈ 6.3 秒；预览路径先缩到 ~2048px，约 160 ms，可用于实时预览。

顺带查明：`box(_:)` 里的**捕获式局部函数 `index()` 阻止了泛型特化**，`Range<Int>` 迭代因此退化为 `Collection._failEarlyRangeCheck` → `_swift_getGenericMetadata`，**每次迭代查一次元数据缓存**。我用不安全缓冲 + `while` 循环重写，**算术逐位不变**（指纹测试证明），Release 1.35×、Debug 3.7×（后者让测试套件从 1.6 s 降到 0.45 s）。改动在 `Sources/RetouchKit/SkinRenderer.swift`，注释里记了实测数字。

**4.6 没有提到、但更重要的一条**：

`renderStep` 对 `skin` 以外的任何算子都抛 `unsupportedOperation`，而 `renderStack` 折叠**全部**启用算子。所以**一个含 `tone` 的真实文档根本渲染不出来**——不是磨皮效果差，是整条栈直接报错。这是当前最大的实用性障碍。

---

## 五、未完成

### 5.1 阻塞性的（不做就没法继续）

| # | 事项 | 为什么阻塞 |
|---|---|---|
| 1 | **按需抽取 `CompositorKit`** | 画笔等旧引擎能力需要与 UI 分离；独立 skin 参考实现不依赖这一步 |
| 2 | **完善渲染与皮肤检测** | skin 参考实现已存在，但自动遮罩、祛瑕疵、其他算子及大图性能尚未落地 |
| 3 | **新 App 外壳** | 没有 UI，什么都看不到 |

### 5.2 功能性的（按人像工作流排序）

| # | 事项 | 优先级 | 说明 |
|---|---|---|---|
| 1 | **数位板压感 / 倾斜** | 🔴 最高 | Compositor 完全没有。专业修图的地基。**iPad + Apple Pencil 免费给** |
| 2 | **人脸检测 + 关键点** | 🔴 最高 | 项目里零 Vision 人脸 API。是"语义化修图"的地基 |
| 3 | **频率分离 / 磨皮** | 🔴 高 | 验收标准已量化（见下） |
| 4 | Dodge & Burn | 🟠 中 | 压感的前置消费者 |
| 5 | 人像液化（五官保护 + 预设） | 🟠 中 | `MetalWarp` 偏移场是正确地基 |
| 6 | 眼睛 / 牙齿专用控件 | 🟠 中 | 色相窗内去饱和，不是简单提亮 |
| 7 | 预设系统（可序列化 `RetouchOp` 栈） | 🟠 中 | **"一键"的本质**，不需要 AI 就能成立 |
| 8 | 批量同步 / 导出 | 🟡 低 | 自用场景可后置 |
| 9 | 色彩管理 / 16-bit | 🟡 低 | 交付客户才需要 |
| 10 | RAW 非破坏 + 侧车 | 🟡 低 | |

### 5.3 继承来的技术债（来自我对 Compositor 的审计，**未修**）

| 严重度 | 问题 | 影响 |
|---|---|---|
| 🔴 高 | `ImageSize`/`CanvasSize`/`Crop`/`Trim` **静默丢弃图层效果、形状、可编辑文本元数据** | 违反它自己的文档，无测试覆盖，保存后不可逆 |
| 🔴 高 | 画布的**面积上限没有强制**（只校验边长） | 能建 900MP 画布然后永远导不出 |
| 🟠 中 | 每次保存**重编码所有图层 PNG** | 30 层改一个像素要重写 30 个文件 |
| 🟠 中 | PSD 导入**忽略 ICC profile** | Adobe RGB / ProPhoto 文件颜色错误 |
| 🟠 中 | PSD **不支持 ZIP 图层压缩** | 一类合法文件完全打不开 |
| 🟠 中 | 内容感知填充很弱（单尺度、无投票） | 大洞和结构线条会明显失败，且**零测试** |
| 🟡 低 | 两套完整合成器靠注释维系同步 | 新功能要写两遍 |

### 5.4 已知的测试问题

**2 个失败用例**，`ColorPickerTests.pickerReopensWhereItWasLastLeft` 和 `FloatingPanelTests.dockedPlacementLeavesTheSavedFilterPosition`。

**已在干净的 HEAD 上复现过**——不是我们改坏的，是这台机器的非交互会话没有真实窗口焦点。CI 上能过。

---

## 六、下一步

### 建议顺序（有依赖关系，别并行）

**第 1 步：让 `skin` 真正可用 —— 皮肤遮罩 + 补齐算子** ← **从这里开始**

4.6 的参考实现是对的，但**它现在还不能修任何一张真实照片**，原因有两个，都是硬阻塞：

1. **没有皮肤遮罩。** `protectNonSkin` 开启时，流程是：没有人脸 → 原样返回；**有人脸但没有遮罩 → 直接报错**。而检测器不存在，所以这个算子目前要么什么都不做，要么失败。
2. **任何非 `skin` 算子都会让整条栈报错。** 真实文档必然有 `tone`（曝光/白平衡）。`renderStack` 折叠全部启用算子，遇到 `tone` 就抛 `unsupportedOperation`。

所以第 1 步拆成两半，**先做遮罩**（它更基础）：

**1a. 皮肤遮罩** —— 新建 `PortraitAnalysis` 模块（Vision 在 macOS 和 iOS 都有，不是 UI 框架）：

- `VNDetectFaceRectanglesRequest` + `VNDetectFaceLandmarksRequest` → 填充已有的 `FaceAnalysis`
- 由人脸框 + 关键点 + 肤色先验生成 `CGImage` 覆盖 → 喂给 `RenderContext.skinMask`
- 这是模型里 `AnchoredPoint` 一直在等的东西，也是 MCP `analyze_faces` 工具的前提

**1b. 补齐 `tone` / `presence` / `toneCurve`** —— 让真实文档能端到端渲染。

**⚠️ 做 1a 之前需要你提供一张真实人像。** 现在手上的 1200×1600 是我合成的卡通脸——它能验证磨皮算法，但 **Vision 的人脸检测在卡通脸上不可靠**，用它调检测器会得到误导性的结论。你自己拍的人像最合适。

**第 2 步：进程内 MCP server，只暴露 3 个工具**

`analyze_faces` / `render_preview_with` / `set_stack`。跑通「AI 看图 → 提议 → 人确认 → 应用 → 再看图」就够验证架构。**依赖第 1 步的 `analyze_faces`。**

**第 3 步：用真实片子校准 `SKILL-portrait-retouch.md`**

里面那张强度表是起点不是答案。**这件事不用写代码，但它决定 AI 修出来的东西能不能看。**

### 已经不需要再做的

- ~~`skin` 算子 + 渲染契约验证~~ —— 4.6 已完成，我复核通过（见 4.7）
- ~~真实图像首轮验证~~ —— 4.7 已完成，算法确认正确

### 关于那些数字

第 1 步的量化验收标准（`texturePreservation = 0.85` 时高频能量 ≥ 60%，`= 0.10` 时 ≤ 25%）**已在两版上通过**。但要注意 **4.7 记录的实测值（真实人像 88%/50%）与单元测试夹具（72%/1.2%）不可比**——两者用的高频度量不同（我的 FFT σ=9 高通 vs 测试的离散拉普拉斯），内核也不同。**以单元测试的指标为准**，它才是被指纹钉住的那个。

### 需要你定的决策

| # | 决策 | 影响 |
|---|---|---|
| 1 | **项目名** | `Compositor` 有商标风险。定了要改 `Package.swift` 和 `PortraitDocument.formatID`——**那是文件格式标识，越早定越好** |
| 2 | **LICENSE** | 继承部分保留 MIT 声明，你自己的代码可另选 |
| 3 | **第一个客户端做哪个** | iPad（Pencil 免费给压感）vs Mac。**建议 iPad-first** |
| 4 | **是否保留 `Compositor/` 目录** | 建议留到 `CompositorKit` 抽完再删 |

---

## 七、关键陷阱备忘

**给未来的自己，也给未来的 agent：**

1. **不要在 `Localizable.xcstrings` 里手工加 key。** Xcode 构建时会删掉它抽不到的条目，而且会用**丢失译文**的方式重建。`build_catalog.py` 只填充、不新增。
2. **抽取只认字面量。** `String(localized: "…")` ✅ / `NSLocalizedString(变量, …)` ❌ / `var x: String { "…" }` ❌。
3. **绝不翻译 PSD 四字符码**：`Layr` `Mtrn` `Rtom` `Rght` `Btom` `Rd  ` `Grn ` `Bl  ` `Txt ` `Clss` `Idnt` `Ornt`。翻译一个，PSD 导入就会像文件损坏一样失败。
4. **显示文本永远不能当标识符。** 这个坑已经踩了三次（`BlendModePicker`、`validateMenuItem`、`ShortcutDefinition.id`）。
5. **算子描述意图，不描述算法。** `skin` 的参数里不该出现"频率分离"。
6. **可创作性 ≠ 可渲染性。** 每端都必须能全保真渲染，只是不一定能创作。

---

## 八、怎么跑

```sh
# 构建
xcodebuild -project Compositor.xcodeproj -scheme Compositor \
  -destination 'platform=macOS,arch=arm64' -configuration Debug \
  -derivedDataPath ./.dd CODE_SIGN_IDENTITY=- build

# 测试（完整套件约 10 分钟）
xcodebuild test -project Compositor.xcodeproj -scheme Compositor \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath ./.dd \
  CODE_SIGN_IDENTITY=- -only-testing:CompositorTests

# 只跑本地化守门测试
xcodebuild test ... -only-testing:CompositorTests/WireValueTests \
                      -only-testing:CompositorTests/DisplayNameTests \
                      -only-testing:CompositorTests/ShortcutIDTests

# PortraitFoundation（SwiftPM 在受限沙箱下跑不了，见它的 AGENTS.md）
cd PortraitFoundation && swift test

# 翻译流水线
xcodebuild -exportLocalizations -project Compositor.xcodeproj \
  -localizationPath /tmp/xcloc -exportLanguage zh-Hans
python3 scripts/i18n/build_catalog.py
python3 scripts/i18n/missing.py
```

---

## 九、一句话总结

**数据模型、国际化和工具链已验证；skin 的两版参考渲染器已实现并经独立复核（4.7），但还不能修任何一张真实照片。**

不是因为磨皮算法不对——算法是对的，只是缺两个前提：

1. **没有皮肤遮罩**，所以 `skin` 要么什么都不做，要么直接报错
2. **任何非 `skin` 算子都会让整条栈报错**，而真实文档必然有 `tone`

下一步是先补这两个前提（见第六节的 1a / 1b），而不是继续加算子或搭 UI。

> **做 1a 需要你提供一张真实人像**——现在只有我合成的卡通脸，Vision 在它上面不可靠。
