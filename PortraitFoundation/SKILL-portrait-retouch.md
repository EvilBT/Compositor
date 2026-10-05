---
name: portrait-retouch
description: Retouch a portrait end to end — analyse the face, decide strengths from measured skin data, apply in the order a retoucher works, and verify the result by looking at it. Use when asked to retouch, beautify, grade, or "make this portrait look better"; when applying a preset to a portrait; or when asked why a portrait looks wrong.
---

# 人像修图

> **这是模板，不是教条。** 里面的数字是**起点**，你必须用自己的片子校准成自己的口味——不同肤色、不同光线、不同客户要求，正确值都不一样。
>
> 但这个文件的**形式**是重点：修图方法论应该住在这里，而不是硬编码进 App。**改它不用发版。**

## 当前原型可执行的闭环（2026-10-05）

当前只暴露 `analyze_faces`、`render_preview_with`、`set_stack` 三个 MCP 工具。
仅支持 `skin`、`tone`、`presence`、`whiteBalance` 和点 `toneCurve`。
下面完整工作流里的祛瑕疵、液化、眼牙专用操作、光影、调色、批量是目标，尚未实现；
不要把示例工具名当作现有能力。用 `tools/list` 返回的 schema 判断能做什么。

当前步骤：

1. `analyze_faces` 获取当前栈、版本、人脸和遮罩；查看原图与遮罩。
2. 一次加入一个已支持操作，用 `render_preview_with` 看候选。
3. 获得人的确认后，把返回的**完整 canonical stack**、`preview_id`、
   `revision`（作为 `expected_revision`）、`session_id` 和 `confirmed: true`
   交给 `set_stack`。确认字段只是客户端声明，不代替真实人的批准。
4. 应用后再次 `analyze_faces` 取当前栈，再用 `render_preview_with` 查看结果。
   当前撤销是原生宿主的 `PortraitSession.undo()`，没有第四个 MCP 撤销工具。

### 首张实片的初步校准

样本 `0229_95_1.jpg`（7008×4672），带刘海、眼妆、面部亮片/珠饰及低调灯光。
检测到 1 张脸；遮罩是关键点 + 脸颊色度先验的保守估计，并非通用皮肤分割模型。
原生分辨率脸部特写的对比：

| 候选 | strength | texturePreservation | radius（原始像素） | 高频能量保留 |
|---|---:|---:|---:|---:|
| 保守 | 0.30 | 0.85 | 12 | 96.3% |
| 标准 | 0.50 | 0.70 | 12 | 85.4% |
| 强 | 0.65 | 0.55 | 12 | 70.6% |

三档在遮罩为零处都没有像素改动。特写中保守档保留了细纹理，标准/强档逐渐更平滑。
**这张照片优先提议保守档**，不要默认抹掉化妆和装饰，也不要把低调灯光自动改成明亮。

### 第二张实片：用户已确认男性人像的下限（2026-10-05）

样本 `20261005.jpg`（6240×4160，自然光、裸肤、可见毛孔、半框眼镜、双人）。
检测到 2 张脸。前三个候选的测量值与逐像素复现完全一致（96.9636 / 87.0025 / 73.0124）。

但**前三档只覆盖了工具最温和的一段**。固定 `strength 0.65` 把 `texturePreservation`
继续推低后，用户在其中选定：

| | strength | texturePreservation | 用户判断 |
|---|---:|---:|---|
| **男性标准档** | **0.65** | **0.30** | **选定**。理由：男性磨皮过度不自然 |
| 更轻 | 0.65 | 0.10 | 过了 |
| 最轻 | 0.65 | 0.00 | 过了 |

**结论：这个参数不是"越低越好"，对男性人像的下限约为 0.30。**
用户同时提出：**强度应当区分性别**（明确说可以后实现）。


这个样本的全脸亮度标准差约 0.098、覆盖比例约 0.38；前者包含灯光与妆容，
**不能直接套下面的“>0.06 → 强磨皮”表**。`blemishDetectionAvailable = false` 时，
`blemishFraction` 是占位值，不能解释成“没有瑕疵”。覆盖率低或遮罩不确定时先核对边界。

当前只有一个人的一张照片，以上数值是样本级校准，尚未证明适用于不同肤色、年龄、
角度或照明。判断纹理要看原生分辨率特写，不只看缩小的整图；选择应以人的审美为准。

---

## 什么时候用

- 被要求修一张人像、"修好看点"、"磨皮"、"调色"
- 把预设应用到一组人像
- 被问"这张为什么看着不对"
- 任何要动 `skin` / `blemish` / `eyes` / `teeth` / `reshape` 算子的场合

**不要**用于：风景、产品、纯图形。人像的规则会把这些修坏。

---

## 铁律

违反任意一条都会做出肉眼可见的失败：

1. **先看，再改。** 任何修改之前必须先 `analyze_faces`。**不许凭猜测设强度。**
2. **改完必须看。** 每次应用后调 `render_preview`。看不到结果的修改等于没修。
3. **一次一层。** 不要一口气写完整栈然后祈祷。一层 → 渲染 → 看 → 下一层。
4. **提议与应用分离。** 默认先 `render_preview_with` 给方案，等人确认再 `set_stack`。
5. **绝不越界。**
   - `texturePreservation` 低于 **0.30** 会出塑料脸
     （**这个下限不是普适常数。** 本文档早先写 0.45，那是从一张浓妆女性照片推出来的；
     用户在自然光的男性人像上选定 0.30，并指出男性应比女性更保守。
     **取值取决于被摄者**——见上面的「第二张实片」和下面的性别说明）
   - 巩膜提白超过 **0.35** 会让眼睛显得假
   - 牙齿去黄超过 **0.6** 会让牙失去立体感
   - 液化幅度单次超过 **0.35** 会开始扭曲五官比例
6. **不动不该动的。** 痣、雀斑、疤痕、皱纹往往是这个人的特征。**除非被明确要求，不删。**

---

## 工作流

严格按这个顺序。这是修图师实际的顺序，也是引擎的 `phase` 顺序——**不要自己重排**。

### 第 0 步：分析（永远第一步）

```
analyze_faces(photo_id)
```

读这些数字，它们决定后面每一步的强度：

| 字段 | 含义 | 怎么用 |
|---|---|---|
| `skinTone.luminanceStdDev` | 皮肤纹理/噪点下限 | **< 0.03** → 皮肤本来细腻，磨皮强度砍半<br>**> 0.06** → 需要正常或偏强 |
| `skinTone.blemishFraction` | 瑕疵密度 | **< 0.005** → 基本不用去瑕疵<br>**> 0.02** → 需要重点处理 |
| `skinTone.meanColor` | 平均肤色 | 判断偏黄/偏红/偏青的基调，决定白平衡方向 |
| `skinTone.coverage` | 皮肤占人脸比例 | 太低（< 0.5）说明检测不准或脸部被遮挡，**降级为保守处理** |

### 第 1 步：定基调（`develop`）

**先解决曝光和色偏，再谈修饰。** 在一张偏色的照片上磨皮是浪费时间。

```
set_module_param(photo, "tone", "exposure", …)
set_module_param(photo, "whiteBalance", "temperature", …)
```

- 目标：皮肤落在中间调，高光不溢出，暗部有细节
- **不要在这一步追求"好看"**，这一步只求"中性"。风格在第 5 步做
- 用 `render_preview` 确认，看直方图不要相信感觉

### 第 2 步：修形（`reshape`）

```
reshape_feature(photo, feature: "jawline", amount: …)
```

- 幅度：**单次 −0.25 到 +0.25 之间**，需要更多就分两次
- 顺序：脸型 → 下颌 → 下巴 → 鼻子 → 眼睛 → 嘴
- **眼睛和嘴最后动**，因为它们对比例最敏感
- 每次改完必须 `crop_closeup` 看一眼——小幅度液化在缩略图上看不出来，在特写上很明显

### 第 3 步：修脏与磨皮（`retouch`）

**先修脏，再磨皮。** 反过来会让瑕疵被磨糊、更难处理。

```
// 1. 自动找瑕疵
add_op(photo, "blemish", { "autoDetect": true, "detectionThreshold": 0.5 })
render_preview(photo)   // 看

// 2. 再磨皮
add_op(photo, "skin", {
  "strength": <从上一步的 luminanceStdDev 推>,
  "texturePreservation": 0.6,
  "radius": 12
})
```

强度决策表（**起点，自己校准**）：

| luminanceStdDev | strength | texturePreservation |
|---|---|---|
| < 0.03 | 0.25 | 0.70 |
| 0.03 – 0.045 | 0.40 | 0.62 |
| 0.045 – 0.06 | 0.55 | 0.55 |
| > 0.06 | 0.65 | 0.50 |

> ⚠️ **这张表有两个已知问题，用之前先读：**
>
> 1. **它偏保守。** 全部 `texturePreservation` 都在 0.50 以上，而用户在实片上选定的是
>    **0.30**。照表取值会得到"看不出效果"的结果。**把表里的值当作上限，不是目标。**
> 2. **它没有性别维度。** 用户明确要求区分。当前经验：男性下限约 **0.30**，
>    女性的下限尚未单独测定（`0229_95_1.jpg` 是浓妆，皮肤本身已无纹理，不能用来定这条）。
>    **在补齐之前，遇到男性被摄者主动比表里的值再收 0.15–0.20。**

眼睛和牙齿是**独立算子**，不要用磨皮顺手带过：

```
add_op(photo, "eyes", { "scleraBrightness": 0.15, "scleraWhiteness": 0.20, "irisClarity": 0.15 })
add_op(photo, "teeth", { "whitening": 0.25, "brightness": 0.10 })
```

**眼睛务必 `crop_closeup` 检查**：巩膜有没有被提成纯白？瞳孔有没有被漂白？睫毛根部有没有被误伤？

### 第 4 步：光影（`paint`）

**这一步决定片子是"修过"还是"好看"。**

Dodge & Burn 的笔绘创作需要合适的输入设备；iPhone 必须能全保真渲染已有笔绘结果。当前原型尚未实现此算子。在有笔的设备上：

- 提亮：额头中央、鼻梁、颧骨上方、下巴
- 压暗：脸颊外侧、下颌线、鼻翼两侧、发际边缘
- **先大后小**：先用大半径低强度建立大体块，再小半径高强度做局部
- 每加一层就 `render_preview` 看一次

如果只有 `localAdjustment`（触屏/鼠标）：用椭圆区域做，feather 至少 0.6，避免出现明显的区域边界。

### 第 5 步：调色（`grade`）

**风格在这里做，不在第 1 步。**

```
set_module_param(photo, "colorGrading", …)
set_module_param(photo, "colorMixer", …)
```

人像调色的顺序：
1. 先统一肤色（`colorMixer` 的 orange/red 两个 band，或 `pointColors` 取一个脸颊的采样）
2. 再定整体调子（`colorGrading`）
3. 最后 `toneCurve` 收对比

**肤色是唯一不能妥协的东西。** 定完调子必须回头 `crop_closeup` 看脸颊，确认没有偏绿/偏紫/偏灰。

### 第 6 步：收尾（`finish`）

```
add_op(photo, "vignette", { "amount": -15, "feather": 70 })
add_op(photo, "grain", { "amount": 8, "size": 1.5 })
```

**宁少勿多。** 暗角和颗粒是"最后 5%"，做重了会把前面所有的功夫盖掉。

### 第 7 步：交付前自检

```
compare(photo_id)   // 原图 vs 成片
```

逐条过：

- [ ] `crop_closeup` 看眼睛：巩膜自然吗？瞳孔有神吗？
- [ ] `crop_closeup` 看脸颊：**还有皮肤纹理吗？** 还是塑料？
- [ ] 看发际线和下颌边缘：有没有磨皮溢出到头发/背景？
- [ ] 看牙齿：是不是变成一条白杠了？
- [ ] 对比原图：**这个人还像他自己吗？**
- [ ] 整体：有没有哪里"修过头"的痕迹？

**任何一条不过，回退重做。** 宁可少修一点。

---

## 批量

```
apply_stack_to_batch(photo_ids, stack, sync: true)
```

**同步是按算子分别决定的**（`syncBehavior`），不是整包复制：

| 会迁移 | 不会迁移 |
|---|---|
| `tone` `whiteBalance` `toneCurve` `colorMixer` `colorGrading` `detail` `grain` `vignette` | `dodgeBurn`（手绘光影图，贴到别人脸上光是错位的） |
| `skin` `blemish` `eyes` `teeth` `reshape`（按人脸重新锚定） | `crop`（这是对**这张**照片的构图决定） |

**批量之后必须抽查。** 至少看 3 张：最暗的、最亮的、人脸最大的。强度是按上一张推的，不一定适合下一张。

---

## 常见失败与诊断

| 症状 | 原因 | 修法 |
|---|---|---|
| 塑料脸 | `texturePreservation` 太低 | 提到 0.6 以上；`strength` 降 0.1 |
| 皮肤发灰 | 磨皮把色彩层次一起抹平了 | 提高 `texturePreservation`；在 `colorMixer` 里把 orange 的 saturation 提一点 |
| 眼睛假 | 巩膜提白过头 | `scleraBrightness` 降到 0.2 以下，改用 `scleraWhiteness` |
| 牙齿一条白杠 | `preserveSeparation` 太低 | 提到 0.7 以上 |
| 磨皮溢出到头发 | 皮肤蒙版没收缩 | `maskExpansion` 设负值 |
| 液化后五官歪 | 单次幅度太大 | `revert_ai_session`，分两次做 |
| 边缘出现明显圆斑 | `localAdjustment` 的 feather 太小 | 提到 0.6 以上 |
| 修完不像本人 | 全流程累积过头 | 看 `compare`，回退到第 3 步重来 |

---

## 和人的协作

- **先给方案再动手**：用 `render_preview_with` 出 2–3 个候选（保守/标准/强），让人挑
- **解释你在做什么**：不说"我磨了皮"，说"皮肤纹理标准差 0.052，偏粗糙，所以强度取 0.55——你觉得够吗"
- **被要求"再狠一点"时要问清方向**：是皮肤更干净，还是光影更立体？这两个是不同的算子
- **不确定就保守**。修少了可以再加，修过了要重来

---

## 参数速查

| 算子 | 保守 | 标准 | 强 |
|---|---|---|---|
| `skin.strength` | 0.3 | 0.5 | 0.65 |
| `skin.texturePreservation` | 0.75 | 0.6 | 0.5 |
| `eyes.scleraBrightness` | 0.10 | 0.18 | 0.28 |
| `eyes.scleraWhiteness` | 0.12 | 0.22 | 0.32 |
| `teeth.whitening` | 0.15 | 0.30 | 0.45 |
| `reshape` 单特征 amount | ±0.12 | ±0.22 | ±0.32 |
| `vignette.amount` | −8 | −15 | −25 |
| `grain.amount` | 4 | 8 | 15 |

**这些是起点。** 用自己的片子跑一遍，把表改成自己的。
