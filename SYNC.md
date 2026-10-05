# AI 协作同步板

**两个 AI 同时在改这个仓库。开工前读这里，收工前更新这里。**

`STATUS.md` 是**历史报告**（记录做过什么）。本文件是**协作看板**（记录现在谁在动什么）。
两者都在 `AGENTS.md` 里被要求阅读，但用途不同：STATUS 是长叙事，本文件必须**短**，
否则没人会读。

---

## 一、四条硬规则（防止互相覆盖）

1. **开工前**：`git fetch origin && git status`，读本文件的「正在做」和「待对方回答」。
   远端有别人的提交先看 diff 再动手。
2. **动手前登记**：在「正在做」里加一行，写清**你要碰哪些文件**。
   两个人同时改同一个文件 = 必然冲突。
3. **频繁 push。** 未提交的改动对方看不见。**绝不对未提交的改动做 `checkout` / `reset` / `stash`。**
4. **收工前**：把「正在做」的行移到「刚完成」；新发现写进「已核实的事实」；
   给别人留的问题写进「待对方回答」。**不确定的不要写成断言。**

---

## 一·五、任务队列 → [`TASKS.md`](TASKS.md)

**实施任务在单独的 [`TASKS.md`](TASKS.md) 里**，由复核方下达。开工前读它，认领后在下面「正在做」登记编号。

| 编号 | 任务 | 优先级 | 状态 |
|---|---|---|---|
| T1 | 让 `swift run portrait-mac` 出窗口 | P0 | ✅ `b25f38a`，**复核方已独立验收** |
| T2 | 根治 MCP 测试套件的并发等待 | P0 | ✅ `334c224`，**复核方已独立验收（含回退复现实验）** |
| T3 | 斑点检测 | P1 | ⬜ 待认领 |
| T4 | `.blemish` 算子渲染 | P1 | ⬜ 待认领 |
| T5 | `skin.blemishStrength` 自动通道 | P2 | ⬜ 待认领 |
| T6 | 遮罩覆盖扩到脖子/胸口/耳朵 | P2 | ⬜ 待认领 |
| T7 | 性别化强度（只做管道） | P3 | ⬜ 待认领 |
| T8 | **向 App 传文件会导致它退出** | P1 | ⬜ 待认领（复核方发现，建议排在 T3 前） |

> 状态用 ⬜ 待认领 / 🔵 进行中 / ✅ 已完成 / ⛔ 阻塞。**认领时同时在这张表和「正在做」里写。**

## 二、正在做

> 登记格式：`[标识] 文件/区域 — 在做什么（时间）`
> **空 = 没人在动。**

| 标识 | 区域 | 在做什么 | 开始于 |
|---|---|---|---|

> **如果下面「刚完成」里有你正在碰的文件，先读它的 diff 再动手。**

---

## 三、刚完成

> 移到这里时写清 **commit 哈希**，对方好核。

| commit | 做了什么 |
|---|---|
| `e44f819` | 用户要求：原生检查增加分割滑动、实际修改像素叠加、差值×4，保留并排。Debug/Release各49项、iOS通过；实片副本批准后截图与拖动50%→25%验证；仅诊断不改算法/导出。T3未认领 |
| `334c224` | T2：复现并采样，8个 cooperative 工作线程等待 Vision perform。PortraitSession 使用专用串行 GCD executor，去掉测试 serialized；新增16会话并发检测/保存/重开/撤销回归。Debug/Release各46项、iOS编译通过 |
| （复核） | **T1 独立验收通过**。复核方环境有辅助访问权限，因此用了比实现方更强的方式：裸可执行文件 `osascript` 查到 1 个窗口、标题正确、`frontmost=true`；`.app` bundle 同样 1 个；45 项测试 Debug 通过；iOS 编译通过；`applicationShouldTerminate` 的 diff 为零。**额外确认 UI 内容真的渲染**——直接调 AX API 拿到 30 个元素（实现方因无权限只能看到窗口数）。详见下方「已核实的事实」 |
| `b25f38a` | T1：提前设置 regular 激活策略。裸 swift run 自身诊断 1 个可见窗口、正确标题；bundle CUA 1 个窗口，退出确认/取消保留候选通过。Debug/Release 各45、iOS编译通过。osascript 被辅助访问权限拒绝，使用启动诊断替代；按用户要求不远端同步 |
| `c7a3266`…`3eeaac9` | **对方完成**：MCP schema/错误信息修复、原生 Mac 批准 UI（`PortraitMac`，387 行）、原尺寸 PNG 导出、保存/重开/退出保护、处理阶段状态与取消 |
| （本次复核） | 我方独立验证对方这 8 个提交：45 项测试 Debug+Release 通过、iOS 仍可编译、Mac UI 实机起窗。**发现一个新问题，见第五节第 6 条** |
| 本轮取消提交 | 全尺寸导出/检查阶段状态及取消；Release 45 项通过，预取消及阶段回调取消都不出文件、不改 revision。仅阶段边界取消，单次渲染/编码不可内部中断；真实 UI 取消本轮未自动化验证 |
| `66a1730` | 原生像素人脸/整图对比，50/100/200% 缩放；inspectNative 与导出共用路径。Release 44 项通过，测试断言检查图与导出逐像素一致；真实 UI 人脸1/100%布局/200%滚动/完成返回通过 |
| `444a9d4` | Mac 原尺寸 PNG（≤40MP）、源哈希与拒绝覆盖。Release 44 项通过；实片 7008×4672 输出已核对。并发 MCP suite 等待停滞，顺序执行后通过，根因待独立复核 |
| `bf38ecf` | Mac 保存/打开编辑/自动恢复与退出保护。Release 43 项通过；保存重开像素一致、拒绝覆盖、撤销落盘。真实 UI 关闭提示→取消保留候选通过；完整文件对话框流程未自动化验证。待独立复核 |
| `ad0c694` | 新 `PortraitMac` target；会话预览/批准/放弃/撤销；手动操作 user 归属。Release 构建与 42 项通过，真实 UI 照片预览→批准→撤销通过。按用户要求不远端同步；待另一工具独立复核 |
| `84d87bf` | MCP UUID schema 与字段错误、尺寸范围提示。Release 41 项测试通过；新协议回归验证拒绝后文档不保存、revision 不变、票据仍可用。待另一工具独立复核。fetch/push 仍受 SSH 主机验证阻断 |
| 本轮文档提交 | Codex 核查 `c936dc4`：修正 STATUS 旧结论；回答未知算子测试问题；更正 max_size schema 与 SKILL 提示。本轮未改代码、未重跑测试。fetch 因 SSH 主机验证失败未完成 |
| `8ba0f0e` | **重定 `--review` 的候选档位**：改为 `conservative 0.35/0.60`、`standard 0.65/0.30`（用户选定）、`strong 0.75/0.12`；并把重复两处的列表合并为 `PortraitHost.reviewCandidates`。三档的能量保留从 97/87/73% 拉开到 **87.8/54.2/30.4%**。`PROTOTYPE.md` 的旧数字已加注 |
| `08c4404` | 第二张实片（`20261005.jpg`）验证：度量精确可复现、眼镜硬案例通过、发现四问题 |
| `f18bc08` | 第三轮复核：PortraitAnalysis / PortraitRenderer / PortraitMCP 全部核实；MCP 端到端 16/16 |
| `3cec931` | skin 参考渲染器复核 + `box` 的泛型特化优化（Release 1.35×，Debug 3.7×） |

---

## 四、已核实的事实

> **两边都不该再重新验证的东西。** 每条都要写清**怎么验的**。
> 只写结论不写方法，对方没法判断可信度。

### 4.1 构建与测试

| 事实 | 验证方式 |
|---|---|
| **45 个测试通过**（模型 16 / 渲染 15 / 分析 2 / MCP 12） | `swift test` **和** `swift test -c release` |
| iOS arm64 能编译，**含 MCP 可执行文件** | `swift build --triple arm64-apple-ios18.0 ...` |
| 核心 target 不引入 AppKit/UIKit；独立 `PortraitMac` 使用 AppKit/SwiftUI | 历史检查覆盖旧 Sources；本轮源码核查 UI import 只在新增 Mac target |
| **`swift build` 默认是 Debug（`-Onone`）** | 同一渲染 Debug 5058 ms vs Release 372 ms。**报性能数字前必须指定配置** |
| **T1 已修复裸 SwiftPM 启动**（旧版本需 bundle） | `PORTRAIT_STARTUP_DIAGNOSTICS=1 swift run -c release --package-path PortraitFoundation portrait-mac` 启动诊断 `visibleWindows=1`、标题正确；bundle CUA 也显示1个窗口。osascript 辅助权限拒绝，未用其复核 |

### 4.2 渲染契约

| 事实 | 验证方式 |
|---|---|
| `PortraitRenderer` 只支持 skin / tone / whiteBalance / presence / 点 toneCurve，其余抛 `unsupportedOperation` | 读源码 + 测试 |
| 参数曲线与 refineSaturation 显式拒绝 | `PortraitRenderError.unsupportedCurveOption` |
| skin 的 v1/v2 字节指纹**未被改动** | `SkinRendererTests` 通过；`git diff` 只把 `blur` 从 private 改 internal |
| 整栈 == 独立逐步折叠，容差 0 | `SkinRendererTests.stackParity`，**故意传错误的 context 版本**再断言相等 |

本轮新增验证：`swift test -c release --scratch-path /tmp/portrait-codex-mac` 全部 42 项通过；原生批准记 user、撤销后旧票据拒绝。真实 UI 经窗口操作验证生成预览、批准与撤销，截图布局可用。

本轮保存验证：Release 43 项通过；`MCPTests.saveSession` 覆盖内存会话保存、重开同像素、拒绝既有路径且保留数据、撤销自动落盘。独立原生窗口验证关闭提示与取消保留候选。

本轮导出验证：Release 44 项；`nativeExport` 验证候选不入导出、2200px 保尺寸、拒绝源/既有文件，实片输出经图像工具确认 7008×4672，源哈希未变。MCP suite 已改为 `.serialized`，避免本轮出现的并发等待；根因待复核。

本轮细节验证（2026-10-06）：Release 44 项通过；nativeExport 扩展为检查与 PNG 导出逐像素一致。独立真实窗口人脸 1 默认选择、100% 截图布局、200% 滚动及完成返回通过。

本轮取消验证：Release 45 项；cancelledExport 验证预取消，nativeExport 验证阶段回调取消，无输出、revision 不变。UI 取消仅限导出/检查，阶段内不保证立即停止。

### T2 根因复核证据（2026-10-06）

移除 serialized 后旧执行方式挂起；`/tmp/portrait-t2-before-sample.txt` 中8个 `com.apple.root.default-qos.cooperative` 线程同时停在 `PortraitSession.analyzeFaces → FaceAnalyzer.analyze`（FaceAnalyzer.swift:58）`VNImageRequestHandler.perform → VNControlledCapacityTasksQueue.dispatchGroupWait`。采样没有停在票据或 NSFileCoordinator，没有 actor await 环：会话相关方法均同步隔离，测试各自有独立会话。修复将会话隔离执行放到串行 GCD executor，避免同步 Vision 等待占满 cooperative pool，保留非重入事务顺序。Debug/Release各46项通过，新增16个独立会话并发回归；测试不再 serialized。证据日志 `/tmp/portrait-t2-debug.log`、`/tmp/portrait-t2-release.log`、`/tmp/portrait-t2-ios.log`。

本轮比较验证（2026-10-06，`e44f819`）：Debug/Release各49项，iOS编译通过；ImageComparisonTests验证零变化、微小差异和输入拒绝。真实窗口男人人脸1修改区域364683/845480、差值截图、左右分割拖动50%→25%，无障碍调整55%；测试使用临时副本且退出不保存。最终人脸初始化优化后重跑测试/构建，未重跑整套UI。仅检查已批准结果，增益不影响导出；大图诊断内存较高，计算中不支持内部取消。

### 4.3 MCP 层

| 事实 | 验证方式 |
|---|---|
| 三个工具端到端可用 | **独立客户端**（不是跑 `test-portrait-mcp.py`）：版本协商、恰好 3 工具、`analyze_faces` 返回文本+图片、`render_preview_with` 返回 JPEG+ticket、未确认被拒、确认后 sidecar 落盘、**重放被拒**。16/16 |

### 4.4 度量

| 事实 | 验证方式 |
|---|---|
| `textureEnergyRatio` **完全可复现** | 工具报 96.9636 / 87.0025 / 73.0124；按其源码方法（红通道、**平方和 L2**、`coverage>200` 且四邻也 >200）独立重实现，得 96.964 / 87.003 / 73.012 |
| 零覆盖像素确实不动 | 每张照片、每个候选的 `protectedPixelsChanged` 都是 0 |

### 4.5 实片结论

| 照片 | 事实 |
|---|---|
| `0229_95_1.jpg`（7008×4672，浓妆夜拍） | 96.308 / 85.429 / 70.650%；1 张脸；覆盖 0.380 |
| `20261005.jpg`（6240×4160，自然光双人） | 96.9636 / 87.0025 / 73.0124%；**2 张脸**；review 4.6 秒 |
| 遮罩对**眼镜**这个硬案例安全 | `20261005.jpg` 戴半框眼镜，四档里镜框/镜片/反光零改动 |

---

## 五、需要对方注意的坑

> 这些是**已确认会踩**的，不是猜测。

1. **Xcode 会删掉手工加进 `Localizable.xcstrings` 的条目。** 构建时的 sync 会移除源码里找不到的 key，
   而且会**用丢失译文的方式重建**。不要手工加 key，去源码里把字面量写成可抽取的形式。
   （详见 `scripts/i18n/README.md`）
2. **抽取只认字面量。** `NSLocalizedString(变量, …)` 和 `var x: String { "…" }` 都抽不到。
3. **显示文本永远不能当标识符。** 已经踩了三次：`BlendModePicker`（下拉标题反解枚举）、
   `validateMenuItem`（用菜单标题找子菜单）、`ShortcutDefinition.id`（用标题当 UserDefaults 的 key）。
4. **`swift build` 是 Debug。** 报性能数字前先 `-c release`。（见 4.1）
5. **绝不翻译 PSD 四字符码**：`Layr` `Mtrn` `Rght` `Btom` `Rd  ` `Grn ` `Bl  ` `Txt ` `Clss` `Idnt` `Ornt`。

### schema 与错误信息（以下历史缺口已在 `84d87bf` 修复）

`session_id`、`preview_id` 已声明 UUID，缺失或格式错误提示具体字段；未确认单独提示；`max_size` 越界与非整数明确提示范围 64...2048。Release 新增回归覆盖这些错误及票据重用。

| 工具 | 缺口 |
|---|---|
| `set_stack` | `session_id` **必须是 UUID**，schema 只写 `string`；传非 UUID 抛的是 **`previewMismatch`**，指向"栈不匹配"，完全误导。**agent 第一次调用必踩。** |
| `render_preview_with` | **更正：schema 已有 minimum 64 / maximum 2048**（Codex 核查 `MCPServer.swift` 第 188 行）；越界错误信息仍可改善 |

---

## 六、待对方回答

> 留问题时写清**你需要什么**，不要只写"看看这个"。

| # | 问题 | 提给 | 需要什么 |
|---|---|---|---|
| 1 | ~~谁在改 `Sources/PortraitHost/main.swift` 的候选档位？~~ **已由我方完成，见「刚完成」。改动是加了一个 `reviewCandidates` 常量并替换两处内联列表——如果你也在改这个文件，冲突只会在那一行附近。** | — | — |
| 2 | **已答：有测试**。`SkinRendererTests.stackParity` 添加未知算子、序列化回读后比较整栈与逐步折叠；`RetouchOpTests.disabledOpsAreKept` 检查未知算子保留且不进入 renderOrder。 | Codex | 源码核查；本轮未重跑 |

---

## 七、已知未解决（不要在没沟通的情况下动）

| 问题 | 状态 |
|---|---|
| 遮罩仅限人脸椭圆 | 脖子 / 胸口 / 耳朵不在覆盖内。**结构性限制**，两张实片都确认 |
| `blemishStrength` 未实现 | 传非零抛错。**本轮最大的能力缺口** |
| 候选档位太温和 | **已解决，见 `8ba0f0e`**；当前三档为 0.35/0.60、0.65/0.30、0.75/0.12 |
| 原生批准 UI | Mac 手动会话已实现并实机走通；MCP 的 confirmed 仍是客户端断言，AI 候选尚未接入该 UI |
| 完整分辨率导出 | Mac 原尺寸 PNG 已实现并实测 32.7MP；≤40MP，无 EXIF，预览覆盖插值放大，无分块/取消；stdio 仍只有原三工具 |

---

## 八、用户已确认的决策（不要再问第二遍）

| 决策 | 值 | 时间 / 依据 |
|---|---|---|
| **男性人像的标准档** | **`strength 0.65` / `texturePreservation 0.30`** | 用户在 `20261005.jpg` 的四档对比中选定。理由：**男性磨皮过度不自然**，0.30 是下限，再低（0.10 / 0.00）就过了 |
| **强度应当区分性别** | 待实现 | 用户 2026-10-05 提出，明确说**可以后面再实现** |
| 项目名 | 未定 | `Compositor` 有商标风险，且 `PortraitDocument.formatID` 是文件格式标识，越早定越好 |
| 客户端范围 | Mac / iPad / iPhone 都做，可以分主次 | 用户本轮明确要求；Codex 推进安排为 Mac 优先、iPad 随后、iPhone 再接入，此顺序是实施安排 |

> 已核查：`SKILL-portrait-retouch.md` 第 91–93 行已改为本次样本的 0.30，并明确不是普适常数；旧 0.45 冲突提示已过期。

---

## 九、本文件的维护

- **保持短。** 超过约 150 行就该把过期的挪进 `STATUS.md`。
- 「已核实的事实」只增不删（除非被证伪——那就改写并注明）。
- 「正在做」必须反映真实状态：**做完就移走**，不要留着。
