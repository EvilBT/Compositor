# AI 修图闭环：工具面设计

> 2026-10-09。用户明确了最终形态：
> **"让最强的 AI（前沿模型）看我的照片，然后直接通过 MCP 操作修改我的照片。"**
>
> 用户还确认：**桌面端和 iPad 都没有笔**。
> 所以**手工修饰不是主路径**——**人审阅，AI 操作**。

---

## 一、这个愿景和现有架构的关系

**现有的三个工具已经是对的形状**：

```
analyze_faces(photo_id)              → 文本 + 覆盖图
render_preview_with(photo_id, stack) → JPEG + 票据
set_stack(photo_id, stack, ticket, …, confirmed) → 应用
```

**闭环是**：分析 → 提议 → 渲染 → **看** → 迭代 → 人确认 → 应用。

**这正是用户要的。** 问题不在形状，**在"看"这一环太弱**。

---

## 二、⛔ 最被低估的缺口：**AI 看不清**

### 事实

```swift
guard (64...2048).contains(maximumDimension) else { throw PhotoIOError.invalidSize }
```

**AI 最多只能看到 2048 px 的预览。**

在 `20261005.jpg`（6240×4160）上，**2048 px 是 3 倍降采样——毛孔完全消失。**

### 后果

**"皮肤质感"这个目标，AI 恰恰看不到。**

它能判断：整体明暗、色调、构图、大概的磨皮程度。
**它判断不了：毛孔还在不在、磨皮是不是过头了、痣有没有被抹掉。**

**而这几件事正是这个产品的全部价值。**

### 讽刺的是，上游已经解决了这个问题——但只给了人，没给 AI

`PortraitHost` 的 `--review` 模式会产出：

| 产物 | 内容 |
|---|---|
| `face-original.png` / `face-{candidate}.png` | **原生分辨率的人脸特写**（892×892） |
| `face-comparison.png` | 原图 / 保守 / 标准 / 强 四联 |
| `face-metrics.json` | **纹理能量保留、改动像素数、零覆盖改动数** |
| `mask-overlay.png` | 遮罩叠加 |

**这是目前最好的"眼睛"，但它是命令行模式，AI 拿不到。**

---

## 三、建议的工具面

### 3.1 现有三个（保留）

| 工具 | 作用 |
|---|---|
| `analyze_faces` | 人脸、关键点、皮肤遮罩、统计 |
| `render_preview_with` | 提议 + 出预览 + 发票据 |
| `set_stack` | 人确认后应用 |

### 3.2 ⭐ 必须新增的四个

#### ① `inspect` — **让 AI 看清**（最高优先级）

```
inspect(photo_id, target, region?, stack?)
  target: "full" | "face" | "region" | "texture"
```

| target | 返回什么 | 给 AI 判断什么 |
|---|---|---|
| `full` | 整图缩略 | 构图、整体明暗 |
| `face` | **原生分辨率人脸特写** | 五官、妆容、装饰物 |
| `region` | **指定区域的 1:1 裁切** | 局部细节 |
| `texture` | **一小块纯皮肤的 1:1 裁切**（如 300×300） | **毛孔、噪点、磨皮是否过头** |

**`texture` 是关键词**：AI 不需要看整张脸来判断毛孔，**它需要看一小块 1:1 的皮肤**。
**一次调用传几百 KB，换一个能判断"是不是塑料脸"的能力。**

> 对照：`photoshop-mcp` 的 `get_preview` 说 "once per major step, not per atomic tool"。
> **我们也要给使用纪律，但前提是那一张图必须够清楚。**

#### ② `compare` — **让 AI 做前后对比**

```
compare(photo_id, stack, region?, mode)
  mode: "sideBySide" | "split" | "difference"
```

`difference` 尤其重要——**上游在 `ImageComparison.swift` 里已经实现了**
（差值 ×gain、改动像素叠加、预乘正确的洋红叠色）。
**它现在是 Mac UI 的功能，不是 AI 的功能。**

**AI 看差值图，比看两遍原图/结果图更容易发现"哪里被改了"。**

#### ③ `measure` — **给 AI 数字，不只是图**

```
measure(photo_id, stack, region?) → {
  textureEnergyRatio,      // 纹理能量保留
  changedPixels,           // 改了多少像素
  protectedPixelsChanged,  // 零覆盖区是否被动过（应为 0）
  coverage,                // 皮肤占比
  luminanceStdDev          // 皮肤粗糙度
}
```

**这些数字 `PortraitHost` 已经在算了**，只是没通过 MCP 暴露。

**AI 同时看图 + 看数字，判断质量比只看图可靠得多。**
**尤其"零覆盖区改动 = 0"这种硬约束，数字比肉眼可靠。**

#### ④ `capabilities` — **让 AI 知道能提什么**

现状：instruction 字符串里**硬编码**了 `"Only skin, tone, presence, whiteBalance and point toneCurve are implemented"`。
**这必然和 `PortraitRenderer` 的 switch 漂移。**

```
capabilities() → {
  operations: [{kind, params, rendered: true/false, phase, authoring}],
  limits: {maxPreviewSize, processVersions}
}
```

**从 `RetouchOpKind` + `PortraitRenderer` 的实际支持集合派生，不是手写。**

> 参照 `photoshop-mcp` 的 `command_list`（817 条命令，带 `enabled` 状态）。

### 3.3 建议新增的两个（次要）

| 工具 | 理由 |
|---|---|
| `job_list` / `job_cancel` | 长分析要能报进度、能取消。**但 3090 上分析是亚秒级，优先级可降** |
| `render_preview_with` 加 `max_size` 之外的 `region` 参数 | 让预览本身就聚焦在关心的区域 |

---

## 四、闭环应该长什么样

```
人： "把这张的皮肤弄好"

AI 1. analyze_faces          → 有几张脸、皮肤占比、粗糙度
AI 2. inspect(target=texture) → 看清毛孔（1:1 裁切）
AI 3. capabilities           → 我有哪些算子可用
AI 4. render_preview_with    → 提议 0.65/0.30，拿到票据
AI 5. inspect(region=…)       → 放大看磨皮结果
AI 6. measure                → 纹理能量 54%，零覆盖改动 0
AI 7. compare(mode=difference)→ 确认只改了该改的地方
AI 8. （不满意）调参数回第 4 步
AI 9. 给人看 + 说明理由        → 人批准
AI 10. set_stack(confirmed)  → 应用
```

**每一步都是请求/响应，不是实时画面。**
**实测命令往返 16.5 ms——一次完整闭环十几次调用也就几百毫秒。**

---

## 四·五、⭐ 云端模型的硬约束 —— 决定了 `inspect` 怎么设计

> 用户已明确：**「基本不跑本地 Agent 模型，优先接入云端前沿大模型」**。
> 所以 `inspect` 的设计要按**云端模型**的物理约束来，不是按本地显存。

### 约束一：**模型会内部降采样你的图**

主流云端视觉模型**收到大图后会自己缩到约 1024–2048 px** 再处理，超出的像素白花 token。

### 约束二：**token 成本随像素走**

一张图的 token 数大致正比于像素。**2048 px 的整图 ≈ 1500+ token；300×300 的裁切 ≈ 100 token 以内。**

### ⭐ 推论（这条是整个设计的支点）

> **送一小块 1:1 的裁切，比送一整张降采样的图，既便宜、又清楚。**

| 送什么 | token | 模型实际看到的毛孔 |
|---|---|---|
| 2048 px 整图 | ~1500+ | 6240 → 2048，**降采样 3 倍，毛孔消失** |
| **300×300 的 1:1 裁切** | **~100** | **不降采样，毛孔全在** |

**便宜 15 倍，而且信息量更高。** 因为模型的瓶颈是**内部降采样**，不是**你给的像素不够**。

**所以 `inspect` 的核心不是"给更大的图"，而是"给正确的裁切"。**

### 约束三：**多轮闭环会累积成本**

一次修图闭环十几次调用，每次带图。**所以：**

- **能用数字的地方不要传图**（`measure` 优先）
- **要传图就传最小的、最有信息量的那一个**
- **不要重复传同一张图**

---

## 五、⚠️ 一个必须面对的现实

**前沿模型能不能判断"皮肤质感好坏"？**

- 它能看出**明显的塑料脸**
- 它能读懂**数字**（纹理能量 4% vs 82%）
- 它**未必能分辨"自然的细腻"和"轻微的过度磨皮"**——那需要经验

**所以正确的设计不是"让 AI 自己判断"，而是：**

1. **给 AI 数字**（客观、可复现）
2. **给 AI 1:1 的图**（能看出毛孔级别）
3. **给 AI 方法论文档**（`SKILL-portrait-retouch.md`——那是"品味"的载体）
4. **给人最终否决权**（`set_stack` 的 `confirmed` 必须由人给）

**`SKILL-portrait-retouch.md` 在这个架构里的地位被提升了**：
**它是 AI 唯一的"审美依据"。** 而它现在只有一张实片的校准数据（男性 0.65/0.30）。

**所以校准 SKILL 不是收尾工作，是核心工作。**

---

## 六、对任务队列的影响

| 任务 | 变化 |
|---|---|
| **新：`inspect` 工具** | ⭐ **最高优先级**——没有它，AI 是瞎的 |
| **新：`measure` 工具** | 高——把已有的统计暴露出去，成本很低 |
| **T11 的 11d** | 升级为 `capabilities` 工具，**优先级提高**（AI 靠它发现能力） |
| **新：`compare` 工具** | 中——`ImageComparison.swift` 已有实现 |
| **T4 / T13** | **不变，而且更重要**——没有笔，AI 是唯一能生成光影图和修补的手段 |
| **T10（分割接入）** | 选型改 ONNX，优先级可降（3090 上不再是长任务） |
| **SKILL 校准** | **从收尾工作提升为核心工作** |

---

## 七、未核实

- **没有测过前沿模型对 1:1 皮肤裁切的判断力**——这是整个方案的未知数
- **没有估算过传图的 token 成本**（一张 300×300 的 1:1 裁切 vs 一张 2048 全图）
- **没有验证** `inspect` 的实际延迟（读图 + 裁切 + 编码，估计几十 ms，未测）
