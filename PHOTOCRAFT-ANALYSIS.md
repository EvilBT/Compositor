# PhotoCraft 分析（2026-10-09）

> 对象：[photocraft.one](https://photocraft.one/zh-cn/) · [storytold/photocraft](https://github.com/storytold/photocraft)
> 目的：判断它与本项目（Compositor + PortraitFoundation）的关系——**是对手、是地基、还是参照**。

---

## 一、事实（已核实，非宣传）

| 项 | 值 | 来源 |
|---|---|---|
| Star / Fork | **29,408 / 4,121** | GitHub API |
| 仓库创建 | **2026-09-30**（9 天前） | API |
| 最近推送 | 2026-10-09 06:24（**1.1 小时前**） | API |
| 提交速度 | **100 个提交 / 5 小时**（含多名人类贡献者） | API |
| 语言 / 许可 | **Rust** / Apache-2.0（站称 MIT OR Apache-2.0） | API |
| 规模 | **332,366 行 Rust**，864 文件，**24 个 crate**，4,378 个测试 | 克隆后实测 |
| 最新发布 | **v0.5.0**，23 个产物（macOS/Win/Linux/FreeBSD） | Releases |
| 平台 | macOS · Windows · Linux · FreeBSD · **Web(WASM)** | README |
| 自评状态 | **early alpha** | README 徽章 |

**它是 ArtCraft 生态的一员**：ArtCraft、ArtCraftX、DesignCraft、VectorCraft、EffectCraft、FilmCraft、LightCraft、PdfCraft。
**提交作者里有 "Claude"**——这个项目本身就是 AI 重度参与的。

**⚠️ 值得注意的一点**：9 天 29k star ≈ **3,400 star/天**。这是极高的速度。工程看起来是真的
（24 crate、强制分层、语料测试、CI 记分卡），但**项目极年轻、处在热度曲线上**。

---

## 二、它的核心架构思想

### 「**Everything is a command**」

500+ 条命令注册在一个注册表里。**UI、CLI、JSON 控制通道、MCP server 全部按 id 派发同一条命令。**

> 这与本项目的 `RetouchOp` 是同一个洞察——**但推得更远**。
> 我们只有 21 种算子、3 个 MCP 工具；他们把这个模式做到了**整个编辑器的每一个菜单项**。

### 强制分层

```
L0 geom cms color raster psd codecs tablet
L1 doc
L2 ops paint algo text vector
L3 compose gpu format
L4 io plugins
L5 engine         ← Session + 命令注册表
L6 ui-egui automation  ← MCP server
```

**由 `cargo xtask layers` 自动检查**：一个 crate 只能依赖更低的层。
`psd` / `codecs` / `cms` 不依赖工作区任何东西。**`ui-egui` 以下不许用 egui/winit。**

### 其他硬规则（写在 `AGENTS.md`）

| 规则 | 内容 |
|---|---|
| **永不崩溃 > 功能** | 非测试代码**禁止** `unwrap`/`expect`/`panic!`/`todo!`，**clippy 强制** |
| **禁止 `unsafe`** | 工作区设 `unsafe_code = "forbid"`，唯一例外是隔离的 `photocraft-tablet` |
| **输入派生数字是敌意的** | 用 `get()` 不用 `[]`，`checked_*`，**给递归设界** |
| **不假设格式或颜色** | 位深（8/16/32f）与色彩模型（RGB/Gray/CMYK/Lab）都是**运行时数据** |
| **Clean-room** | 研究 PS 只看**行为与外观**，从公开规范实现，不抄代码/着色器/配置 |

---

## 三、它有、而你们缺的（差距清单）

| 能力 | PhotoCraft | 本项目 |
|---|---|---|
| **压感 / 倾斜 / 旋转** | ✅ 独立 `tablet` crate（macOS AppKit + X11） | ❌ **你们的 #1 缺口** |
| 图层 / 蒙版 / 剪贴 / 27 混合模式 | ✅ | 🟡 Compositor 有，未抽取 |
| 16 种调整图层（曲线、色阶带直方图） | ✅ | 🟡 部分 |
| **PSD 双向无损** | ✅ **309 个语料文件验证** | 🟡 Compositor 有，忽略 ICC、不支持 ZIP 压缩 |
| **Dodge / Burn / Healing / Spot Healing 工具** | ✅ 已实现 | 🔴 **T13/T4 还没做** |
| ICC 色彩管理、4 色彩模型、8/16/32 位 | ✅ | ❌ |
| GPU 合成器（wgpu / Metal） | ✅ | 🟡 Compositor 有 |
| **500+ 命令 + MCP + JSON 控制通道 + CLI** | ✅ | 🟡 3 个 MCP 工具 |
| 批处理 CLI | ✅ | ❌ |
| **语料库测试**（真实 PS 文件作 oracle） | ✅ psd-tools / ag-psd / PngSuite 固定版本 | ❌ **只有 2 张照片** |

---

## 四、它没有、而你们有的（你们的差异化）

| | PhotoCraft | 本项目 |
|---|---|---|
| **iOS / iPad / iPhone** | ❌ **路线图和 README 都没有** | 🎯 **明确目标** |
| **人脸检测 / 皮肤遮罩** | ❌ | ✅ Vision + FaRL/SAM3 |
| **人像专用修饰**（磨皮、祛瑕疵、眼牙、液化） | ❌ **一个都没有** | ✅ 21 种算子 |
| **中文界面** | ✅ **有**（14 种语言，zh-hans 2,255 条）——更正：我上轮标了未知 | ✅ 773 条（2 种语言） |
| 摄影修图的方法论（SKILL） | ❌ | ✅ 270 行 |

---

## 五、它自己的诚实评估（**这段最有价值**）

> **"real Photoshop parity is still well below 50%"**
>
> **"A professional could switch for daily work: roughly 25–35%"**
>
> "on first public use they found broken basics (text selection offset, **214 shortcut failures**,
> panels resizing themselves, an immovable crop frame, folders that wouldn't collapse, lag on layout PSDs)
> **that all counted as 'live' in `parity.md`**"
>
> 记分卡：**129 个偏好设置里 67 个没有任何代码读取**；**25 个性能预算里只有 3 个达标**；
> **150 层微移场景会让 GPU 合成器崩溃**

**这份诚实度罕见，而且是对他们的信任加分。** 但也说明：**"每个菜单项都接了命令"衡量的是接线，不是行为。**

---

## 六、战略判断

### 结论：**不换地基，但把它的工程规矩全部偷过来**

**理由（三条，按重要性）：**

1. **平台是决定性的。** 你们要 iPad + iPhone；**PhotoCraft 没有 iOS 路径**。
   Web(WASM) 理论上能在 iPad Safari 跑，但拿不到 Apple Pencil 的原生压感，
   而这正是你们最想要的东西。**换过去等于放弃三端目标。**

2. **它是通用编辑器，你们是人像工具。** 它**没有任何**人脸检测或人像修饰。
   你们真正的差异化（皮肤质感、光影、斑点）**在它那里一行都没有**。
   换过去你们要从**更后面**开始。

3. **成熟度不足以托付。** 它自己说 early alpha、专业可用度 25–35%、150 层会崩。
   而你们已有可运行的原型 + 55 个测试 + 两张实片验证过的渲染器。

### 但——**它的工程规矩比你们严，这部分要认真学**

| # | 学什么 | 为什么 |
|---|---|---|
| 1 | **"Everything is a command" 推到极致** | 你们的思想对了（`RetouchOp` 是数据），但只覆盖 21 个算子；他们已经覆盖整个菜单面 |
| 2 | **`cargo xtask layers` —— 用工具强制分层** | 你们的 `PortraitCore → RetouchKit → PortraitMCP` 是分层，但**没有任何自动检查**。已经出现过"RetouchKit 不该依赖 X"这类只能靠人守的约定 |
| 3 | **语料库测试（真实 PS 文件作 oracle）** | 你们**只有 2 张照片**。他们固定了 psd-tools / ag-psd / PngSuite 的版本并进了 CI |
| 4 | **CI 维护的记分卡 + 性能预算** | 他们的 `cargo xtask scorecard` 会**统计"没有任何代码读取的设置"**——这个指标能抓住"接了线但没实现" |
| 5 | **`docs/parity.md`：自动生成"每个菜单项，活的还是缺的"** | 你们可以对 **`RetouchOpKind` 的 21 个算子**做同一件事：哪些渲染器真实现了、哪些抛 `unsupportedOperation` |
| 6 | **"永不崩溃 > 功能"，且用 clippy 强制** | 你们的"校验要宽松"是同一个精神，但他们把它**变成了构建失败** |
| 7 | **`AGENTS.md` 带"5 分钟上手"阅读表** | 你们的 AGENTS.md 已经不错，但他们的**结构化程度更高**（读什么、为什么、按什么顺序） |

### 还有一条**反面对照**

> PhotoCraft 的目标是 **"1:1 Photoshop parity"**——同样的菜单、快捷键、行为。

**你们的目标不是这个。** 你们要的是**人像修图的专用工具**，把 PS + 像素蛋糕替换掉。
**追随 PS 1:1 会把你们拖进一个无底洞**——他们自己有 100+ 人贡献都只做到 25–35%。
**保持"窄而深"，这是你们唯一的结构性优势。**

---

## 七、具体建议（按成本排序）

| 成本 | 做什么 |
|---|---|
| **零** | 读他们的 `AGENTS.md`、`docs/roadmap.md`（诚实评估）、`docs/scorecard.md`。**半小时，收益大** |
| **低** | 给我们自己的 op kinds 做一份 `docs/parity.md` 式的表：**21 个算子各在哪一端**（渲染器实现了/未实现/检测有无） |
| **低** | 把"分层不可越界"变成**一条可执行的检查**（哪怕只是个 grep 脚本） |
| **中** | 把 CI 记分卡的思想搬过来：**统计"定义了但没人读的字段"**——你们的 `PortraitDocument` 里恐怕也有 |
| **中** | 扩充语料：现在只有 2 张照片，**至少加一组 PS 导出的对照图** |

---

## 八、克隆后的实测对比（2026-10-09）

已克隆到 `~/Developer/photocraft`（47 MB，depth 1）。

### 8.1 规模：**不是同一个量级**

| | PhotoCraft | 本项目 |
|---|---:|---:|
| 代码 | **332,366 行 Rust** / 864 文件 / 24 crate | 40,259 行（PF 3,770 + Compositor 36,489） |
| **测试** | **4,378 个 `#[test]`** / 139 测试文件 | 592 个（PF 60 + Compositor 532） |
| 文档 | **70 个 md** | ~15 个 md |
| 本地化 | **14 种语言**（zh-hans 2,255 条） | 2 种（773 条） |
| 最大 crate | `ui-egui` **98,219 行** | PortraitFoundation 全部 3,770 行 |

**它的 `ui-egui` 一个 crate 就是你们全部代码的 2.4 倍。**

### 8.2 ⭐ **MCP 设计：这是最有价值的一条**

**他们用「少数通用工具 + 命令注册表」，你们用「少数专用工具」。**

| 它暴露的工具 | 作用 |
|---|---|
| `command_list` | **列出引擎所有命令：id、label、菜单路径、快捷键、参数说明、当前是否可用**（带 filter / enabled_only） |
| `command_run` | **按 id 跑任意命令**，返回 JSON 结果；长命令可 `wait: false` 变成后台任务 |
| `command_batch` | 一次调用跑多条命令，**减少往返** |
| `job_list` / `job_cancel` | **后台任务的进度与取消**（进度 0–1、消息、已用时间） |
| `doc_state` | 文档状态 JSON：**图层树、历史、选区、活动图层** |
| `doc_render` | 渲染拼合结果，返回 PNG 图像 |
| `doc_open` / `doc_save` / `doc_export` / `doc_new` / `doc_close` / `doc_activate` | 文档生命周期 |

**这直接回答了我们 T11 的 11d。** 我们打算"加一个 `get_capabilities` 工具"，
而他们的 `command_list` 就是那个想法的**通用形式**——**不硬编码能力清单，而是从注册表派生**，
还附带 `enabled` 状态（现在能不能用）。

**而且它解决了我们还没解决的问题**：`job_list` / `job_cancel`。
我们的 Mac UI 有取消，**但 MCP 层没有**——而 T10 的 SAM3 分析要 **24–30 秒**，
没有进度和取消的 MCP 工具是没法用的。

**`command_batch` 也值得学**：修图的"一次一层"工作流天然是多步的，
我们的 agent 现在只能一次次往返。

### 8.3 后台任务模型（`crates/engine/src/jobs.rs`）

> "Background jobs: long commands run on a worker thread, report progress and can be cancelled"

命令通过 `ctx.progress(0.1, "Finding subject")` 上报进度，`JobCtx` 同时携带**取消标志**。

**这正是 T10 需要的**：24–30 秒的分析必须能报进度、能取消。
**建议把这套模型作为 T10 的前置**，而不是等接完 SAM3 才发现没法取消。

### 8.4 安全模型（`crates/automation/src/security.rs`，315 行）

- **256 位 bearer token**，用系统 CSPRNG 生成，**常数时间比较**
- **有界行读取**（`MAX_REQUEST_BYTES`），超长请求正确丢弃并继续读下一行
- 连接数上限、批量上限、读写超时、**仅回环 TCP**

**我们的 MCP 是 stdio（无网络面），所以没有等价风险**——但如果将来加 HTTP 传输，
**这份实现是现成的参照**。

### 8.5 它有、而我们确实没有的（补充）

| | 证据 |
|---|---|
| **CJK 字体回退**（Inter/JetBrains Mono 无中日韩字形，按 OS 探测回退） | `crates/ui-egui/src/cjk_fonts.rs`（有测试） |
| **14 种语言**目录 + 语言选择器 + 系统 locale 探测 | `crates/ui-egui/src/i18n/*.tsv` + `tests/system_locale.rs` |
| **翻译许可证说明** | `i18n/LICENSE-translations.txt`，且文档写明"中文措辞为原创，未提取专有翻译资源" |

**最后一条值得注意**：他们**为翻译单独写了许可说明**，并声明是原创措辞。
**我们做中文翻译时没有考虑这一点**——如果术语表借鉴了 Adobe 官方译法，
在 Apache-2.0 下发布时可以更明确一些。

### 8.6 更新后的结论

**规模差距是数量级的**（代码 8×、测试 7.4×），所以"换地基"在人力上也不现实。

**但三个具体的东西应该立刻学**：

1. **`command_list` 式的能力发现**（替代我们硬编码在 instructions 里的算子清单）→ 并入 **T11**
2. **`job_list` / `job_cancel` 的后台任务模型**（进度 + 取消）→ **提到 T10 之前做**
3. **`command_batch`**（减少往返）→ 并入 T11

---

## 九、我没有核实的

- **没有实际构建或运行 PhotoCraft**（22 MB 仓库，24 crate，未克隆）
- **没有验证** "309 个测试文件重保存无损还原 307 个"这一具体数字
- **没有核实** "500+ 命令"与"16 种调整图层"的实际数量
- **没有确认** 它的中文界面支持情况
- **没有验证** star 增长是否有异常（9 天 29k 很高，但我没有证据说它不真实）
