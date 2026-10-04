# 项目状态

> 工作文档。每次开工先看这里，收工前更新这里。
>
> 最后更新：`b8d2d0b`

---

## 一、这是什么

**目标**：一套自用的人像修图软件，替代现在的 **PS + 像素蛋糕** 工作流。三端（Mac / iPad / iPhone），并且**让 AI 能直接控制它**。

**起点**：fork 了 [Compositor](https://github.com/robbietilton/Compositor)（MIT，macOS 图像编辑器，36k 行 Swift + C）作为像素引擎的参照与来源。

**当前状态一句话**：**地基和工具链都验证过了，应用本身一行代码还没写。**

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
| **PortraitFoundation 数据模型** | ✅ 完成 | 2483 行，16 测试全绿 |
| i18n 工具链 | ✅ 完成 | `scripts/i18n/` |
| **CompositorKit 抽取** | ❌ 未开始 | Phase 0 的核心动作 |
| **RetouchRenderer 实现** | ❌ 未开始 | 只有协议，零实现 |
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
portrait-foundation  b8d2d0b  ← 全部工作，已推送
```

53 个文件改动，+12579 / −127 行。

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

跨平台人像修图的**声明式修饰模型**。`Sources/PortraitCore/`，2483 行。

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

---

## 五、未完成

### 5.1 阻塞性的（不做就没法继续）

| # | 事项 | 为什么阻塞 |
|---|---|---|
| 1 | **抽取 `CompositorKit`** | 新 App 不能依赖 Compositor 的 UI 层。画笔引擎/光栅/降采样/C 内核都要抽出来 |
| 2 | **实现 `RetouchRenderer`** | 目前只有一个协议。没有它就没有任何修图能力 |
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

**第 1 步：`skin` 算子 + 渲染契约验证** ← **建议从这里开始**

理由：它是**唯一能一次性验证三件事**的地方，而且验收标准已经量化好了。

1. **"意图 vs 算法"这条规则在真实实现里撑不撑得住**
2. **`processVersion` 机制可用** —— 同一文档在两版下渲染不同且都可复现
3. **渲染契约能落地** —— `renderStack` 必须等于折叠 `renderStep`，容差 0

**量化的验收标准**（上一轮实测得出）：

| 面板 | 纹理能量保留 |
|---|---:|
| 原图 | 100% |
| 朴素模糊 | **4.4%** ← 塑料脸 |
| 频率分离 · texture 0.85 | **81.6%** ← 目标 |

断言：`texturePreservation = 0.85` 时高频能量 ≥ 60%；`= 0.10` 时 ≤ 25%。

**第 2 步：进程内 MCP server，只暴露 3 个工具**

`analyze_faces` / `render_preview_with` / `set_stack`。跑通「AI 看图 → 提议 → 人确认 → 应用 → 再看图」就够验证架构。

**第 3 步：用真实片子校准 `SKILL-portrait-retouch.md`**

里面那张强度表是起点不是答案。**这件事不用写代码，但它决定 AI 修出来的东西能不能看。**

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

**地基（数据模型）和工具链（构建/测试/UI 自动化/翻译）都验证过了；应用本身一行代码还没写。**

下一个动作是 `skin` 算子——它同时验证渲染契约、`processVersion` 机制和"意图 vs 算法"这条规则，而且有量化的验收标准（纹理能量 81.6% vs 4.4%）。
