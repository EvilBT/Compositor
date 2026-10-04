---
name: portrait-retouch
description: Retouch a portrait end to end — analyse the face, decide strengths from measured skin data, apply in the order a retoucher works, and verify the result by looking at it. Use when asked to retouch, beautify, grade, or "make this portrait look better"; when applying a preset to a portrait; or when asked why a portrait looks wrong.
---

# 人像修图

> **这是模板，不是教条。** 里面的数字是**起点**，你必须用自己的片子校准成自己的口味——不同肤色、不同光线、不同客户要求，正确值都不一样。
>
> 但这个文件的**形式**是重点：修图方法论应该住在这里，而不是硬编码进 App。**改它不用发版。**

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
   - `texturePreservation` 低于 **0.45** 会出塑料脸
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

眼睛和牙齿是**独立算子**，不要用磨皮顺手带过：

```
add_op(photo, "eyes", { "scleraBrightness": 0.15, "scleraWhiteness": 0.20, "irisClarity": 0.15 })
add_op(photo, "teeth", { "whitening": 0.25, "brightness": 0.10 })
```

**眼睛务必 `crop_closeup` 检查**：巩膜有没有被提成纯白？瞳孔有没有被漂白？睫毛根部有没有被误伤？

### 第 4 步：光影（`paint`）

**这一步决定片子是"修过"还是"好看"。**

Dodge & Burn 需要笔，**iPhone 上没有**。在有笔的设备上：

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
