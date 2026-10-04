# MCP 工具面

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
