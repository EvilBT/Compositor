# Notes for AI agents — PortraitFoundation

这是**一个人像修图 App 的地基**：跨平台（Mac / iPad / iPhone）的声明式修饰模型。目前已有**数据模型与 `RetouchKit.SkinRenderer` 的版本化 CPU 参考实现，没有 UI、没有 App**。

现在它住在 Compositor 仓库的一个子目录里，将来会拆成独立仓库。**把它当成独立项目对待**：里面的东西不该依赖 Compositor，也不该反向影响它。

---

## 先读这个：为什么先做数据模型

其余所有事情都建立在它上面，而且**全都是从第一天就要成立的**，后期补不回来：

| 目标 | 依赖什么 |
|---|---|
| AI 直接控制软件 | 栈是纯数据 → MCP 工具是薄映射，不需要跨进程桥 |
| 一键预设 | 预设 = 栈的一个切片 |
| 三端同步 | 栈可序列化 → 手机读 Mac 的结果 |
| 批量同步 | 每个算子声明 `syncBehavior` |
| 非破坏 + 撤销 | 每个算子是一个独立 undo step |
| **算法持续改进** | `processVersion` 让旧文档保持旧渲染 |

---

## 五条不可妥协的规则

改这个包之前必须读完。**违反任意一条，整个设计就塌了**——而且塌得不明显，要几个月后才发作。

### 1. 算子描述**意图**，不描述算法

`skin` 的参数里**不应该**出现"频率分离""表面模糊"这类算法名。它表达"把皮肤弄好看"，引擎自己选算法，由 `PortraitDocument.processVersion` 决定选哪一代。

**这意味着：改进算法不许改变已有文档的渲染结果。** 要改行为就 bump `currentProcessVersion`，让老文档继续用老路径。

这是唯一能让"算法持续改进"和"预设永远有效"共存的办法。Lightroom 的 Process Version 就是干这个的。**没有它，你每优化一次磨皮，就悄悄改变了用户存过的每一个预设。**

### 2. 栈按**相位**排序，稳定

`RetouchOpKind.phase` 决定顺序，同相位内保留添加顺序（`renderOrder` 用的是稳定排序）。

**不要**加"让用户随便拖顺序"的功能。修图师的心智顺序是「修形 → 磨皮 → 光影 → 调色」，随意拖会产生"先锐化后降噪"。

### 3. 区域**锚定**，不按像素寻址

`AnchoredPoint` 只有三种 space：`.image` / `.face(index:)` / `.landmark(faceIndex:landmark:)`。

**任何新算子要指位置，都必须用 `AnchoredPoint`。** 不接受裸坐标 `(x, y)`。

Landmark 相对坐标是给 AI 用的那个——它在重新检测后稳定、对裁剪鲁棒。

### 4. **可创作性 ≠ 可渲染性**

**每个算子在所有平台都必须全保真渲染。** `authoringRequirement` 只决定 UI 要不要提供编辑入口，**绝不**决定渲染。

理由：iPhone 必须能导出 iPad 上做的片子。手绘的 Dodge & Burn 光影图在手机上要一模一样地渲染出来，只是不能画。

**如果某个新算子真的做不到全平台渲染，那是一个需要显式讨论的架构决策，不是加个 `default:` 能糊过去的。**

### 5. 不认识的算子必须**存活**

`RetouchOpKind.unsupported` + `JSONValue` 存在的唯一理由：三端更新节奏不同，旧版设备打开新版写的文档，必须原样保留看不懂的算子——**不丢弃，也不拒绝整个文档**。

`RetouchOpKind` 的 `Codable` 是**手写双向**的，因为合成版遇到未知 case 会抛错——那正好是必须活下来的场景。

---

## 改代码时的具体陷阱

### 加一个 `RetouchOpKind` case，必须同时改四处

1. `RetouchOpKind` 枚举本身
2. `init(from:)` 的 switch
3. `encode(to:)` 的 switch
4. 测试里的 `allKinds`

**漏掉 2 或 3 会静默失败**——那个 case 就是编不进文件或读不出来。测试里的 `allKinds` 是唯一一份算子清单，就是为了拦住这个。

### 不要给那两个手写 switch 加 `default:`

`init(from:)` 里的 `default:` 是**留给未知算子的**，不是留给"我懒得写"的。给 `phase` / `authoringRequirement` / `syncBehavior` 加 `default:` 也是错的——它们**故意是穷尽的**，这样加 case 时编译器会拦住你。

### 别用合成的 `Codable` 处理"字段可选"的容器

Swift 合成的解码器**不会**为缺失的 key 填默认值——属性写了 `= 1` 也没用，它会抛 `keyNotFound`。

`PortraitDocument` 因此是手写解码的。**Compositor 的 `.comp` manifest 就踩了这个坑**：`format` / `version` / `colorSpace` 在 Swift 里看着是可选的，实际上是必需字段。

### 校验要宽松，不要严苛

`checkFace` 在文档还没有人脸检测结果时**故意不报错**——因为同步过去的预设可能先于检测到达。拒绝会让一个完全正常的预设变成打不开的文档。

**新写校验时问自己：这个失败会让一份合法的文档打不开吗？** 如果是，那就不该失败。

---

## 构建与测试

### 正常环境

```sh
cd PortraitFoundation
swift build
swift test
```

### 受限沙箱下 SwiftPM 起不来

**只有会话的文件策略是 `workspace-write` 时才会遇到。** 策略是 `danger-full-access` 时 `swift test` 正常工作（已验证：16 个测试全绿）。

受限时 SwiftPM 会调 `sandbox-exec`，在外层沙箱里被拒：
`sandbox-exec: sandbox_apply: Operation not permitted`

**这时用 `swiftc` 直编。** 已验证可用的两条命令：

```sh
SDK=$(xcrun --show-sdk-path --sdk macosx)

# 1. 库本身（Swift 6 语言模式，严格并发）
swiftc -typecheck -sdk "$SDK" -target arm64-apple-macos15.0 -swift-version 6 \
  -module-cache-path ./.cache/modules \
  Sources/PortraitCore/JSONValue.swift Sources/PortraitCore/RetouchOp.swift

# 2. 测试文件（需要 Testing 框架和宏插件）
FW=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks
PLUGINS=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing
swiftc -typecheck -enable-testing -sdk "$SDK" -target arm64-apple-macos15.0 -swift-version 6 \
  -module-cache-path ./.cache/modules -I ./.cache -F "$FW" -plugin-path "$PLUGINS" \
  Tests/PortraitCoreTests/RetouchOpTests.swift
```

第 2 条依赖第 1 条先 `-emit-module` 出 `.cache/PortraitCore.swiftmodule`，完整序列见 `README.md`。

**注意 `-module-cache-path` 必须指向工作区内**，否则写入 `~/Library` 会被沙箱拒绝。

**`.cache/` 和 `.build/` 是构建产物，跑完删掉**，别提交。

### 想跑而不只是 typecheck

SwiftPM 不可用时，可以编一个临时可执行文件把关键行为真跑一遍（库源码 + 一个 `main.swift`）。**typecheck 通过 ≠ 运行正确**，前向兼容那套手写编解码尤其需要真跑。

---

## 许可证与归属

**Compositor 是 MIT，Copyright (c) 2026 Wonder Assembly LLC。**

从它继承的代码必须保留版权声明和许可文本。参考实现（画笔引擎的算法思路、`RasterSnapshot` 的稀疏表示、投影几何等）如果搬过来，**在文件头注明来源**。

`Compositor` 这个名字可能有商标，**新项目要换名**。

---

## 目录

```
Sources/PortraitCore/
  JSONValue.swift     任意 JSON 无损容器 —— 前向兼容的载体，别在这里"优化"
  RetouchOp.swift     文档模型、算子、锚点、校验、渲染契约
Tests/PortraitCoreTests/
  RetouchOpTests.swift
Sources/RetouchKit/
  SkinRenderer.swift  版本化 CPU 磨皮参考实现
  README.md           使用方式、验收指标与已知限制
Tests/RetouchKitTests/
  SkinRendererTests.swift
README.md             五条规则 + 关键类型速览 + 验证方式
MCP-TOOLS.md          AI 控制层设计（工具面、schema、视觉闭环、三端拓扑）
SKILL-portrait-retouch.md   修图方法论 —— 这是产品 know-how，不是代码
```

---

## 还没做（下一步的依赖顺序，不要并行）

1. **渲染器实片验证与扩展** — `skin` 的两版参考实现和零容差一致性测试已完成。先验证真实人像、检测遮罩与性能，再扩展 `tone` / `presence` / `toneCurve`。实现限制见 `Sources/RetouchKit/README.md`。
2. **进程内 MCP server，只暴露 3 个工具** — `analyze_faces` / `render_preview_with` / `set_stack`。跑通「AI 看图 → 提议 → 人确认 → 应用 → 再看图」就够验证架构。
3. **用真实片子校准 `SKILL-portrait-retouch.md`** — 里面那张强度表是起点不是答案。

**从这里开始，所有渲染都必须经过 `RetouchRenderer` 协议**，不许有"直接改像素"的旁路。`renderStep` 是定义，`renderStack` 是允许融合的优化，两者必须一致，而且**第一天就要有一致性测试**——Compositor 有两套完整合成器靠注释维系同步，那是它最大的技术债。

---

## 约定

- 注释解释**为什么**，不解释**是什么**。这个包里注释密度很高是故意的：每条规则都有代价，写清楚代价，下一个人（或下一个 agent）才不会顺手违反它。
- 美式拼写（color，不是 colour）。
- 公共 API 全部 `public` + 文档注释；内部实现不需要。
- 值类型优先，`Sendable` 由编译器检查。
- **不确定的约束不要写成断言。** 宁可宽松，也不要让一份合法文档打不开。
