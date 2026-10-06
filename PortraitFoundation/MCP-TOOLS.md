# MCP 工具面

> 当前实现：`PortraitMCP.MCPServer` + `portrait-mcp` stdio 宿主，只暴露 `analyze_faces` / `render_preview_with` / `set_stack`。其余工具是规划。启动、确认票据、保存与限制见 [PROTOTYPE.md](PROTOTYPE.md)。原生 UI 和 HTTP 尚未实现。

让 AI 直接控制这个软件。当前成熟方案（Adobe 官方做法、Photoshop/Blender MCP 的实现）都收敛到同一个结构：

```
AI 客户端 (Claude / ChatGPT / Cursor)
  ├─ Skill   ← 「怎么修得好」：方法论、决策规则、护栏
  └─ MCP     ← 「能做什么」：动作
        ↓
   你的 MCP Server  ← 进程内，没有桥
        ↓
   RetouchOp 栈  →  渲染
```

**Skill 和 MCP 是互补的，不是竞争的**（Anthropic 官方口径）。MCP 提供动作，Skill 提供程序性知识。

---

## 你和 Photoshop 的关键区别：不需要那座桥

Photoshop 的 MCP 实现**必须**是 `MCP Server ⇄ UXP WebSocket ⇄ Photoshop`，因为 Photoshop 没有可编程的文档格式——编辑状态是不可序列化的内部模型，AI 只能像遥控黑盒一样操作它。

你不必如此。`RetouchOp` 栈是纯数据，所以：

```
MCP Server (进程内)  →  直接读写 RetouchOp 栈  →  App 重绘
```

没有 WebSocket，没有插件沙箱，没有跨进程 RPC。**集成成本大约是 Photoshop 方案的 1/10，可靠性高一档。** 前提是核心操作本来就是纯粹的、可序列化的、可撤销的、可预览的——也就是 `RetouchOp` 那五条规则在守的东西。

---

## 三层粒度：必须都有

只给 `apply_beauty_filter()` 是错的——那样 AI 永远只能做一键美颜，等于自己把产品降级成像素蛋糕。

| 层 | 用途 | 工具 |
|---|---|---|
| **L1 意图级** | 今天的模型 | `suggest_retouch` `apply_preset` `compare` |
| **L2 模块级** | 半年后的模型 | `set_module_param` `get_stack` `set_stack` |
| **L3 空间级** | 精细控制 | `heal_spot` `add_local_adjustment` `reshape_feature` |

模型能力在快速变化。**只有 L1 就锁死了自己的上限。**

---

## 工具清单

### 读取与分析

| 工具 | 返回 |
|---|---|
| `get_photo_info(photo_id)` | 尺寸、已检测人脸数、栈摘要 |
| `analyze_faces(photo_id)` | 人脸框、关键点（归一化）、肤色统计、曝光统计 |
| `get_stack(photo_id)` | 完整 `RetouchOp` 栈 |
| `describe_op_kind(kind)` | **参数 schema**：范围、默认值、`authoringRequirement`、`syncBehavior` |
| `list_presets()` | 预设名与摘要 |

### 渲染（闭环的关键）

| 工具 | 返回 |
|---|---|
| `render_preview(photo_id, max_size?)` | **图片** — 当前栈的结果 |
| `render_preview_with(photo_id, stack, max_size?)` | **图片** — 假设栈的结果（"如果这样改会怎样"） |
| `compare(photo_id, stack_a?, stack_b?, max_size?)` | **并排图** |
| `crop_closeup(photo_id, region, max_size?)` | **局部放大图** — 修眼睛/牙齿时必需 |

`render_preview_with` 是整个工具面里最有价值的一个：它让 AI 可以**先看再决定**，而不是盲改。有了它，`suggest_retouch` 甚至可以只是一个 Skill 里的多轮流程（渲染几个候选 → 比较 → 挑一个），不需要服务端启发式。

### 修改

| 工具 | 说明 |
|---|---|
| `add_op(photo_id, kind, params, position?)` | 返回 `op_id`；省略 position 时按相位自动落位 |
| `update_op(photo_id, op_id, params)` | 部分更新 |
| `remove_op(photo_id, op_id)` | |
| `set_enabled(photo_id, op_id, enabled)` | A/B 不删除 |
| `set_stack(photo_id, stack)` | 整体替换，用于预设 |
| `set_module_param(photo_id, module, param, value)` | L2：`("tone", "exposure", 0.3)` |
| `heal_spot(photo_id, at, radius?, source?)` | L3：`at` 是 `AnchoredPoint` |
| `add_local_adjustment(photo_id, region, adjustments)` | L3 |
| `reshape_feature(photo_id, feature, amount, face?)` | L3 |

### 批量与会话

| 工具 | 说明 |
|---|---|
| `apply_preset(photo_id, preset_name)` | |
| `apply_stack_to_batch(photo_ids, stack, sync?)` | 按每个算子的 `syncBehavior` 决定能否迁移 |
| `save_preset(name, stack)` | |
| `export(photo_ids, preset?)` | |
| `revert_ai_session(photo_id?, session_id)` | 移除该会话的所有算子，**不碰用户自己的活** |

---

## 关键 schema

### `analyze_faces`

```json
// input
{ "photo_id": "A1B2" }

// output — 归一化 0–1，原点左上，y 向下（和 AnchoredPoint 同一套约定）
{
  "faces": [{
    "index": 0,
    "boundingBox": { "origin": [0.31, 0.12], "size": [0.22, 0.31] },
    "roll": -2.4,
    "landmarks": {
      "faceCenter": [0.42, 0.27], "cheekLeft": [0.355, 0.31], "chin": [0.42, 0.43],
      "eyeLeft": [0.375, 0.235], "eyeRight": [0.465, 0.232], "noseTip": [0.42, 0.30]
    },
    "skinTone": {
      "meanColor": [0.78, 0.62, 0.53],
      "luminanceStdDev": 0.041,
      "coverage": 0.83,
      "blemishFraction": 0.012
    }
  }],
  "detectorVersion": "vision-1"
}
```

`skinTone` 里那几个数字的存在，是为了让模型**不必猜强度**：`luminanceStdDev` 低说明皮肤本来就细腻、磨皮强度该往下调；`blemishFraction` 高说明瑕疵多、该往上调。

### `render_preview_with`

```json
// input — 传入完整栈，不落盘，不改文档
{
  "photo_id": "A1B2",
  "max_size": 1024,
  "stack": [
    { "id": "…", "kind": { "skin": { "strength": 0.55, "texturePreservation": 0.65, "radius": 12 } },
      "isEnabled": true, "origin": { "user": {} } },
    { "id": "…", "kind": { "eyes": { "scleraBrightness": 0.2, "irisClarity": 0.15 } },
      "isEnabled": true, "origin": { "user": {} } }
  ]
}

// output — MCP image content block，模型真的看得到
{ "content": [
    { "type": "image", "mimeType": "image/jpeg", "data": "<base64>" },
    { "type": "text", "text": "Rendered 1024×768, full stack, 2 ops applied." }
] }
```

**工具必须返回图片。** 只返回 `{"status":"ok"}` 等于让 AI 盲修——这是绝大多数实现失败的地方。MCP 协议原生支持工具返回 image content。

> 有个开源实现的做法是"把渲染图推给用户看的 viewer，但模型看不到"。那是错的一半：模型也必须看到，否则无法迭代；用户当然也要看到，所以两个都要。

### `describe_op_kind`

让模型不必被硬编码就能用 L2/L3 工具——这是让工具面**自描述**的关键。

```json
// input
{ "kind": "skin" }

// output
{
  "kind": "skin",
  "phase": "retouch",
  "authoringRequirement": "anywhere",
  "syncBehavior": "faceRelative",
  "summary": "Evens skin colour and light while preserving pore-level texture.",
  "params": [
    { "name": "strength", "type": "number", "range": [0, 1], "default": 0.5,
      "summary": "Overall amount. Above ~0.75 the skin starts to read as plastic." },
    { "name": "texturePreservation", "type": "number", "range": [0, 1], "default": 0.6,
      "summary": "How much high-frequency detail survives. Below ~0.5 is a bug, not a preference." },
    { "name": "radius", "type": "number", "range": [2, 80], "default": 12,
      "summary": "Detail scale in pixels — roughly the pore size to preserve." }
  ]
}
```

注意 `summary` 里带的是**判断标准**而不只是单位。"低于 0.5 是 bug 不是偏好"——这种信息放在 schema 里，模型才不会写出难看的参数。

### `heal_spot` — 空间定位怎么做

```json
// input
{ "photo_id": "A1B2",
  "at": { "space": { "landmark": { "faceIndex": 0, "landmark": "cheekLeft" } }, "value": [0.08, -0.03] },
  "radius": 0.012 }
```

三种定位方式里：

| 方式 | 精度 | 评价 |
|---|:---:|---|
| `{"space":"image","value":[0.42,0.31]}` | 低 | 模型从缩略图估绝对坐标，误差经常 5% 以上，修不准 |
| **`{"space":{"landmark":…}}`** | **高** | ✅ 通过关键点映射，鲁棒、语义清晰、模型也容易推理 |
| 关键点索引 + 精确偏移 | 最高 | 适合精细控制，但模型负担重 |

**人像场景里 landmark 相对坐标是赢家**，而且它天然复用你本来就要做的关键点检测——零额外成本。

---

## 安全与可控

| 机制 | 怎么做 |
|---|---|
| **每个操作一个 undo step** | `RetouchOp` 天然是一个事务边界 |
| **非破坏** | 改栈，不改像素。永远可以回到原图 |
| **会话级回滚** | 所有 AI 算子带 `origin: .ai(sessionID:)`；`revert_ai_session` 精确移除 |
| **先看后改** | `suggest_retouch` / `render_preview_with` 只渲染，不改文档 |
| **参数校验** | 每个写入都过 `RetouchOpKind.validate()`，返回具体范围而不是静默 clamp |
| **并发冲突** | 复用 Compositor 现成的机制：kqueue 监听 + 内容摘要 + 「Revert / Keep Mine」对话框 |

**最重要的设计原则：`suggest_retouch` 与「应用」必须分离。** AI 先提议、人确认、再应用。这既安全，又让用户从 AI 的建议里学到东西——这比一个"一键美颜"按钮有价值得多。

---

## 三端怎么落地

| 平台 | 方案 |
|---|---|
| **Mac** | ✅ 完整本地 MCP server（stdio）。Claude Desktop / Claude Code 直接配置连接。**主战场，回报最高** |
| **iPad / iPhone** | ❌ 不做外部 MCP server。iOS 无法可靠地跑一个被外部客户端连接的长驻服务 |

但这不是损失，因为核心是**声明式栈**——它天然跨设备：

```
Mac 端（AI 在跑）  ──写入──▶  RetouchOp 栈  ──同步──▶  iPad 精修  ──▶  iPhone 一键出片
```

- iPad 的价值是 **Pencil 精修**，不是被遥控
- iPhone 的价值是 **一键 + 批量 + 随手**，而 AI 生成的栈正好就是"一键"
- iPadOS 26 的窗口/后台能力如果让本地 MCP 变得可行，那是加分项——**别把架构建立在它上面**

---

## Phase 0 先做哪三个

不要一次做完上面那张表。先只做三个，验证闭环：

1. `analyze_faces` → 结构化数据
2. `render_preview_with` → **返回图片**
3. `set_stack` → 应用

只要能跑通「AI 看图 → 提议 → 人确认 → 应用 → AI 再看图」，架构就验证了，**后面只是往表里加工具**。

顺带说一句：`set_stack` 是可以先不做的。只做前两个 + 文件层面的栈读写，闭环就已经成立——这正好也是 Compositor 现在的 `writing-comp-files.md` 那条路。

---

# 附：与 `photoshop-mcp` 的对照复审（2026-10-06，复核方）

参考对象：[alisaitteke/photoshop-mcp](https://github.com/alisaitteke/photoshop-mcp)，**MIT**，
127 个工具（111 原子 + 16 recipe），23 个 MCP prompt。
它**独立地**解出了和本项目相同的问题，因此是一次有价值的外部对照。

**结论：它是很好的工具面参照，但传输层不要抄。**
它必须跨进程桥（AppleScript/COM → ExtendScript，或 UXP 的 HTTP 轮询）才能驱动 Photoshop；
**本项目不需要桥**，因为 `RetouchOp` 是可序列化数据。这条优势在本文件开头已经写明，此处得到外部印证。

## 它做得好、值得我们学的四处

### 1. 结构化错误信封（**最高价值**）

它的形状：

```ts
interface PhotoshopErrorEnvelope {
  ok: false
  code: PhotoshopErrorCode          // 24 个类型化错误码
  message: string
  suggested_next_tool?: string      // ← 让 agent 能自我修复
  suggested_args?: Record<string, unknown>
}
```

并且有一张**模式表**把底层字符串错误映射到 `(code, suggested_next_tool)`——
这正好对应我们的处境：底层抛的是 `SkinRenderError` / `PortraitSessionError`，目前被 `"\(error)"` 拍平。

**我们现在的样子**（`MCPServer.swift`）：

```swift
catch { return response(id: idValue, result: .object([
    "isError": .bool(true), "content": .array([Self.text("\(error)")])
])) }
```

**只有一句人类可读的话，没有机器可读的 code，也没有下一步提示。**

对照 `84d87bf` 刚做的改进：`session_id must be a UUID string.` 已经比 `previewMismatch` 好得多，
但**它仍然只是一句话**。加 `code` 与 `suggested_next_tool` 才是下一级。

### 2. `instructions` 是一份**契约**，不是一句话

它是分节的：HARD RULE / Session bootstrap / State before action / Recipe over atomic /
**Units & conventions** / **Error recovery contract**（含错误码表）。

我们现在是**一整句**：

> `Open photo_id: … Source dimensions: 6240×4160. Analyze first, render a candidate, obtain human confirmation, then set_stack with that preview_id and expected_revision. Only skin, tone, presence, whiteBalance and point toneCurve are implemented. This host is a preview prototype.`

### 3. ⚠️ **坐标系没有说明**（具体缺陷）

`AnchoredPoint` 的 image / face space 是归一化 0–1；landmark 是**有符号的人脸宽度分数偏移**：

```swift
case image                     // Normalized 0–1 across the whole image
case face(index: Int)          // Normalized 0–1 across a detected face's bounding box
case landmark(faceIndex:landmark:)  // face-width fractions
```

**但 instructions 里出现了两次 "pixel"**（来自 `Source dimensions: 6240×4160`），
**却一个字都没提归一化**。agent 读到尺寸后合理地传 `{"value":[3000,2000]}`，拿到的就是错的结果。

对照 `photoshop-mcp` 的 Units 一节：

> All numeric coordinates, widths, heights and bounds are pixels.
> **The server forces pixel/point units around every script — do not translate to inches/cm/percent.**

**它们的单位是像素并明说了；我们的单位是归一化却没写。** 这是必须补的。

（待确认：`AnchoredPoint` 的值是否有 0–1 范围校验。若没有，传像素会**静默**产生错误结果。）

### 4. 没有用 MCP 的 `prompts` 原语

它有 **23 个 prompt**（`prompts/list`、`prompts/get`），把"怎么修图"的方法论直接下发给宿主。
**我们只有 tools**，而 `SKILL-portrait-retouch.md`（270 行方法论）目前是一个客户端得自己去找的文件。

**把 SKILL 通过 MCP `prompts` 暴露，是天然对应。**

### 5. 能力清单硬编码在字符串里

我们的 instructions 里写死了 "Only skin, tone, presence, whiteBalance and point toneCurve are implemented"。
**这句话会和 `PortraitRenderer` 的 switch 漂移。**
`photoshop-mcp` 的做法是提供一个 `get_capabilities` 工具，让宿主主动查询。

## 我们做得比它好的地方（应当保持）

| | |
|---|---|
| **预览-确认-提交的事务** | `preview_id` + `expected_revision` + `confirmed` + 票据重放拒绝。它的 recipe 只是"一个撤销步骤"，**没有 revision 并发保护** |
| **不需要跨进程桥** | `RetouchOp` 是数据；它必须过 AppleScript/COM/UXP |
| **未知算子存活** | 它的工具面是固定的 127 个；我们的文档能携带未来版本写的算子 |

## 它值得单独一提的设计

- **`document_id` 固定**：Photoshop 的活动标签页会被外部改变，所以每次变更都带上 id。
  我们的 `photo_id` 解决同一类问题——**这点我们已经有**。
- **`get_preview` 的使用纪律**："once per major step, not per atomic tool"。
  我们的 `render_preview_with` 是同一角色，值得把这条纪律写进 instructions。
- **`Action Plan` 模式**：一次规划调用产生有序工具列表再执行，减少往返。
  这与"AI 提议 → 人确认 → 应用"的流程同构，可作参考。


## T12 实现核查（2026-10-06）

原始instructions只给源尺寸，未说明坐标单位；文字本身没有两次pixel，此前复审描述不精确。
独立原生探针实际传入image `[3000,2000]`，旧document.validate接受；补校验后抛
`outOfRange(op: "blemish", field: "spots[0].at.value.x", value: 3000, range: 0...1)`。
现有MCP StackCodec尚不接受blemish/localAdjustment，所以同一像素请求原来已返回
`unsupportedOperation`，不会提交或写文档；不是当前可用MCP工具已经静默渲染错位置。

现在统一校验斑点目标、复制源、局部区域中心及路径点：image/face为有限0...1；
landmark为有限、有符号、无硬范围的人脸宽度分数，原点在landmark，两个轴均按脸宽换算。
负偏移和超过一脸宽的偏移允许，避免拒绝跨脸边界/图外区域的合法表达；不能将它们当像素。
该宽松点不自动推断单位，也不会把大数自动缩成0...1。未来开放带坐标工具时仍须遵守契约。
拓展半径、extent和其他参数校验不属于本次T12。未知算子继续原样保留，文件结构未改。

T11对照的设计方向接受：类型化错误/可操作恢复提示、能力单一来源、方法论prompt。
优先维持现有三个工具，用单一能力来源满足11d，不复制Photoshop传输层。
恢复建议必须按本项目事务判定；session_id格式错误应由客户端生成合法UUID，
不是要求重做预览（preview不提供session_id），不能照搬复审例子。
本次不实施T11，也未独立核实参考项目工具数量；后续按具体需求复核。
