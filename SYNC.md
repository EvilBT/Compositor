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

## 二、正在做

> 登记格式：`[标识] 文件/区域 — 在做什么（时间）`
> **空 = 没人在动。**

| 标识 | 区域 | 在做什么 | 开始于 |
|---|---|---|---|
| （空） | | | |

> **如果下面「刚完成」里有你正在碰的文件，先读它的 diff 再动手。**

---

## 三、刚完成

> 移到这里时写清 **commit 哈希**，对方好核。

| commit | 做了什么 |
|---|---|
| （本次） | **重定 `--review` 的候选档位**：改为 `conservative 0.35/0.60`、`standard 0.65/0.30`（用户选定）、`strong 0.75/0.12`；并把重复两处的列表合并为 `PortraitHost.reviewCandidates`。三档的能量保留从 97/87/73% 拉开到 **87.8/54.2/30.4%**。`PROTOTYPE.md` 的旧数字已加注 |
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
| 40 个测试通过（模型 16 / 渲染 15 / 分析 2 / MCP 7） | `swift test` **和** `swift test -c release` |
| iOS arm64 能编译，**含 MCP 可执行文件** | `swift build --triple arm64-apple-ios18.0 ...` |
| `Sources/` 里零 AppKit/UIKit | `grep -rn 'import AppKit\|import UIKit\|import Cocoa' Sources/` |
| **`swift build` 默认是 Debug（`-Onone`）** | 同一渲染 Debug 5058 ms vs Release 372 ms。**报性能数字前必须指定配置** |

### 4.2 渲染契约

| 事实 | 验证方式 |
|---|---|
| `PortraitRenderer` 只支持 skin / tone / whiteBalance / presence / 点 toneCurve，其余抛 `unsupportedOperation` | 读源码 + 测试 |
| 参数曲线与 refineSaturation 显式拒绝 | `PortraitRenderError.unsupportedCurveOption` |
| skin 的 v1/v2 字节指纹**未被改动** | `SkinRendererTests` 通过；`git diff` 只把 `blur` 从 private 改 internal |
| 整栈 == 独立逐步折叠，容差 0 | `SkinRendererTests.stackParity`，**故意传错误的 context 版本**再断言相等 |

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

### schema 与错误信息的缺口（已确认，未修）

| 工具 | 缺口 |
|---|---|
| `set_stack` | `session_id` **必须是 UUID**，schema 只写 `string`；传非 UUID 抛的是 **`previewMismatch`**，指向"栈不匹配"，完全误导。**agent 第一次调用必踩。** |
| `render_preview_with` | `max_size` 实际限定 **64...2048**，schema 只写 `integer`；越界抛 `invalidSize` 不说范围 |

---

## 六、待对方回答

> 留问题时写清**你需要什么**，不要只写"看看这个"。

| # | 问题 | 提给 | 需要什么 |
|---|---|---|---|
| 1 | ~~谁在改 `Sources/PortraitHost/main.swift` 的候选档位？~~ **已由我方完成，见「刚完成」。改动是加了一个 `reviewCandidates` 常量并替换两处内联列表——如果你也在改这个文件，冲突只会在那一行附近。** | — | — |
| 2 | 未知算子（`unsupported`）在 `renderStack` 里的行为是否已测？ | 对方 | 我看到 `renderOrder` 排除它，但没找到专门测试 |

---

## 七、已知未解决（不要在没沟通的情况下动）

| 问题 | 状态 |
|---|---|
| 遮罩仅限人脸椭圆 | 脖子 / 胸口 / 耳朵不在覆盖内。**结构性限制**，两张实片都确认 |
| `blemishStrength` 未实现 | 传非零抛错。**本轮最大的能力缺口** |
| 候选档位太温和 | 三档 texture 0.85/0.70/0.55，但参数可到 0。用户已选 **0.30**（见第八节） |
| 原生批准 UI 缺失 | `confirmed: true` 是客户端断言，不是同意证明 |
| 完整分辨率导出 | 宿主只出 ≤2048px 预览 + 原生脸部特写，不出整图成片 |

---

## 八、用户已确认的决策（不要再问第二遍）

| 决策 | 值 | 时间 / 依据 |
|---|---|---|
| **男性人像的标准档** | **`strength 0.65` / `texturePreservation 0.30`** | 用户在 `20261005.jpg` 的四档对比中选定。理由：**男性磨皮过度不自然**，0.30 是下限，再低（0.10 / 0.00）就过了 |
| **强度应当区分性别** | 待实现 | 用户 2026-10-05 提出，明确说**可以后面再实现** |
| 项目名 | 未定 | `Compositor` 有商标风险，且 `PortraitDocument.formatID` 是文件格式标识，越早定越好 |
| 第一个客户端 | 未定 | 建议 iPad-first（Pencil 免费给压感） |

> ⚠️ **`SKILL-portrait-retouch.md` 第 73 行写着「`texturePreservation` 低于 0.45 会出塑料脸」，
> 与上面的 0.30 冲突。** 那个 0.45 是从一张浓妆女性照片推出来的，**不是普适阈值**。
> 改那条之前先在第五节登记。

---

## 九、本文件的维护

- **保持短。** 超过约 150 行就该把过期的挪进 `STATUS.md`。
- 「已核实的事实」只增不删（除非被证伪——那就改写并注明）。
- 「正在做」必须反映真实状态：**做完就移走**，不要留着。
