# 项目状态

最新用户反馈（2026-10-07）：用户纠正研究目标：最初目的为最佳皮肤质感，瑕疵不应仅从痘痘出发。已在SYNC.md顶部完整记录原话、实现方建议的颜色/明暗/纹理/孤立斑点分工、最终视觉验收，以及给另一AI的检索请求。T3保留为局部辅助通道；VL-AcneSeg未试跑/未选定，不代表整体路线。用户将让另一AI检索；本次仅文档交接，未改实现或任务排期、未运行测试、未远端同步。


最新进度（2026-10-07，T3）：新增PortraitAnalysis/BlemishDetector，采用多尺度内外框均值对比、局部红/暗差、环形邻域一致性、鼻影与高光排除、稳定排序/NMS。默认门槛0.8，只输出可审查候选，不诊断暂时性、不修补照片。全候选圆盘在非零皮肤遮罩内，统计以圆盘交高覆盖像素的并集/高覆盖皮肤像素计。MCP analyze_faces现在提供blemishes、detectorVersion及availability=true；SkinToneStats.blemishFraction不再是占位。新增可选缓存字段，旧缓存仅用冻结遮罩补元数据，PNG不变；文档结构、processVersion、skin算法不改。

两张原片3张脸+2个原尺寸裁切实测：双人2048预览男性1/女性0，装饰预览0；男性原尺寸2（明显下巴红点及脸颊小红点），装饰原尺寸0。宽松初版36/4含鼻影、普通纹理、亮片邻域，收紧后未选深色痣和亮片；不能据此保证所有痣/雀斑不误选。已看四个最终图；分辨率不同会产生不同候选，零值不等于无瑕疵。没有人工标注，不给精度/召回率。照片完整SHA保持、未上传。

Release检测三次中位：双人预览17.0ms、装饰预览6.8ms、男性原尺寸110.5ms、装饰原尺寸76.3ms；总分析（一次，不含照片加载）156.1/110.6/345.1/291.3ms。不是跨设备基准。四份final/v4跨进程候选逐项相同，每份又3次一致且圆盘不越遮罩。独立MCP两图available=true、候选1/0、revision0、栈空。复现runner实跑通过。产物与完整报告 /Users/xiaoman/Developer/assets/blemish-trial/results.md；代码/复现说明scripts/blemish-trial/README.md。

Debug/Release各60项（Core19/Render18/Analysis6/MCP14/Mac3）通过，iOS编译通过，核心无AppKit/UIKit，原skin v1/v2指纹和栈契约通过。新增4检测回归、1MCP缓存升级/协议回归；日志/tmp/portrait-t3-debug.log、/tmp/portrait-t3-release.log、/tmp/portrait-t3-ios.log、/tmp/portrait-t3-protocol.log、/tmp/portrait-t3-runner.log。更新assets/PortraitPrototype.app Release二进制，未退出用户应用，重启生效；未添加原生候选UI。临时Swift scratch/harness清理，实验图与环境保留。按既有要求不远端同步。

剩余：漏非红/轻微瑕疵和鼻影/高光附近，仍可能混淆红痣、妆容、毛囊；须审查候选并允许手工补点。T4实际修补、T5自动通道未做，不能把本轮当祛痘成片。T3待独立复核，下一项T4未认领。

以下为历史记录：

最新进度（2026-10-06，T12）：先读最新同步板，T8由复核方独立8/8验收，原待验收请求已关闭。按插队要求完成坐标说明与校验。实际原生探针image `[3000,2000]`旧validate接受，新validate抛outOfRange，字段spots[0].at.value.x，范围0...1。MCP独立客户端前后同一blemish像素请求均unsupportedOperation且未写文档：当前StackCodec未开放带锚点算子，并非当前MCP已经静默渲染错位。

统一验证blemish目标/复制源和localAdjustment的中心/路径点。image/face有限0...1；landmark为有符号的人脸宽度分数，负值和超过1允许，仅拒绝非有限值，以保留跨边界/图外的合法表达。不能按0...1一刀切，也不自动猜测像素。已补initialize契约：参照系、左上原点/y向下、两轴脸宽偏移、skin.radius像素和spot.radius脸宽分数。未知算子不改，编码格式/processVersion/渲染算法均未改。

Debug/Release各55项（Core19/Render18/Analysis2/MCP13/Mac3）通过，iOS编译通过，核心无AppKit/UIKit，既有v1/v2字节指纹通过。新增3项坐标回归及初始化说明断言。日志/tmp/portrait-t12-debug.log、/tmp/portrait-t12-release.log、/tmp/portrait-t12-ios.log；独立协议前后日志/tmp/portrait-t12-protocol-before.log、/tmp/portrait-t12-protocol-after.log；原生探针新结果/tmp/portrait-t12-core-after.log。照片未改/上传，临时文档未产生。Swift scratch和临时探针/客户端将清理，日志保留。

已读T11复审，接受结构化错误、说明契约、单一能力来源和方法论prompt方向，保留三工具且不复制桥；修正其session_id错误建议，合法UUID应由客户端生成，不必重做preview（preview不提供session_id）。本轮不实现T11。下一任务T3，未认领；按用户既有要求不fetch/push。

以下为历史记录：

最新进度（2026-10-06，T8实现 / 6a23f3f）：文件及URL入口接入有效图片检查和allowDiscard；应用代理持有会话，避免场景重建丢失编辑。退出堆栈来自AppKit末窗口关闭自动退出；增加保留进程和文件入口恢复窗口。关闭窗口后进程保留，Cmd-Q仍走原确认。未改渲染/文档版本。

Debug/Release各52项（既有49+Mac3项）、iOS编译通过，核心无AppKit/UIKit，v1/v2指纹通过。日志/tmp/portrait-t8-debug.log、/tmp/portrait-t8-release.log、/tmp/portrait-t8-ios.log。独立唯一测试实例真实open载入照片，AX标题证实；非图片提示且原照片保持；候选换图取消保留候选，批准未保存后换图取消保留编辑及撤销，Cmd-Q原确认通过。用户源照片及编辑未写，用户运行的应用未动。

CUA Finder图标拖拽多次未送达事件，全屏尝试报告noWindowsAvailable；不声称拖拽通过，T8尚未满足全部验收，留复核方独立验证。本轮不进入T3。更新assets/PortraitPrototype.app Release二进制及图片类型声明，重启生效；暂不远端同步。T8验收后按T3→T4→T5→T10→T6→T7推进。

以下为历史记录：

最新决策（2026-10-06，用户要求收敛探索）：确定当前质量优先方案为 **FaRL + SAM3 BF16 + 自动局部/保守确认 + 核心锁定与距离羽化 + SkinRenderer v2**。SAM3 8bit仅内存备用，完整优化链未复验；SAM3.1不作为默认，不再扩展本轮模型比较。具体证据、边界和接入验收见 `scripts/face-parsing/DECISION.md`。用户暂缓iPad实测。此决策取代旧研究暂停及先T9后SAM3的选型前置条件；无模型T9仍保留为轻量候选，未认领/完成。下一步为应用分析入口、会话缓存和可修正保护遮罩，尚未实现。此次仅文档，未改应用/Swift/保存格式，未重跑历史测试，未远端同步。

以下为历史记录：

最新进度（2026-10-06，保护与羽化探索 / `9a7cc8a`）：用户要求实测组合遮罩与羽化。新增独立诊断脚本、Swift渲染harness和复现说明；未改应用或任何Swift库源码/保存格式/processVersion。用FaRL皮肤类别、局部亮点候选、保护核心扩边和距离smoothstep羽化，另试guided filter和SAM2.1 Hiera Tiny（官方源码revision 2b90b9f5ceec907a1c18123530e92e794ad901a4）。SAM由亮点提示+局部框引导，不是识别贴钻的语义模型，12探针接受5/拒绝7。

夜拍裁切1470×1470、源人脸宽890.9px，扩边3px，羽化3/7/14px；323亮点候选、4852核心像素。全尺寸crop调用既有SkinRenderer v2、radius12，标准0.65/0.30和压力0.85/0.15，总17遮罩/34实际PNG输出。压力档：仅分割4852核心变化/max86；普通高斯羽化4004核心变化/max28，皮肤外35322像素变化；锁核心、guided锁核心、SAM锁核心核心和皮肤外均0。3/7/14档均保持0；宽羽化减少处理面积。guided与距离羽化实际结果有31619像素差异/max15，不能说两者等同，但本次未见明确视觉优势。

无贴钻男人人像对照仍产生51候选/756核心（含鼻尖额头自然反光），证明亮点规则不能作为饰物分类器。未标注ground truth；保护0仅指被检测核心，不能等同所有贴钻完整识别。仍需装饰物语义/上下文或手工补保护。17遮罩/34渲染尺寸、各锁定变体core/non-skin逐像素保持、4个audit源哈希通过；脚本语法/diff检查与遮罩、实际图、羽化扫描图目视核查通过。harness Release构建成功；本轮未重跑Swift49项，未验证CoreML/整图预览一致或无光晕保证。

结果 `/Users/xiaoman/Developer/assets/face-parsing-trial/protection-results.md`，目录protection-night-v2、protection-night-narrow、protection-night-wide、protection-control；feather-sweep.jpg为三档图。日志 `/tmp/portrait-protection-mask-v2.log`、`/tmp/portrait-protection-render.log`、`/tmp/portrait-protection-audit.log`及narrow/wide/control日志。源照片未写，照片未上传。下一步优先改善装饰物识别，再集成保护核心+向外羽化；本实验并非新app功能已经完成。

以下为前轮历史记录：

最新进度（2026-10-06，分割第二轮 / `f43c537`）：加入SegFormer-B5（发布者jonathandinu/face-parsing，revision 758b82e15a0178c9db39c1ff666a8b56e3a550c8），扩到两张实片共3脸；Swin-B、MobileNet、FaRL、SegFormer全部本地CPU跑通。另对双人图以1.65与1.4裁切重复4模型：按源图固定Vision脸框比较皮肤+鼻子分类，FaRL变化0.86/1.00%，SegFormer1.17/1.27%，Swin2.04/1.62%，MobileNet2.66/2.49%。这是裁切稳定性，不是ground-truth准确率。

新增稳定性工具投影各自label图到原图再比较；SegFormer类ID从配置读取，报告记录独立label_names/输入尺寸/权重哈希。20张类别输出（4模型×夜拍1脸、双人2脸、裁切变化2脸）类ID0–18、5张2880×550布局、三个报告所有模型无error及source_unchanged=true断言通过；两张双人图及夜拍/细节图目视核查。脚本语法与diff检查通过。本轮未改Swift/app，未重跑49项；Release宿主为另一照片基准重新构建成功。

视觉发现：浓妆夜拍的贴钻/亮片被四个学习模型当成皮肤，现有色度/高光规则保留部分亮点；因此不能直接用模型皮肤类别替换处理遮罩。FaRL在这两脸上更稳定，Swin精度版更快；SegFormer冷CPU前向双人2.607/2.279秒、夜拍2.615秒，未显示足以定为优先接入的优势。不同对齐、单次冷测和无人工标注限制全部保留。眼镜整个镜片、胡须、贴钻仍需处理策略；下一步优先Swin/FaRL+保护规则，再CoreML/ANE验证，不是现在声称已集成。

结果与中文报告 `/Users/xiaoman/Developer/assets/face-parsing-trial/round2-results.md`，完整图在night-expanded/couple-expanded，细节night-details.jpg，裁切对照couple-crop14、crop-stability.json。源照片未改，照片未上传。另查官方DML-CSR（边缘多任务，老CUDA/Inplace-ABN）和第三方DINOv3+VGG19（列独立胡须类，但未验证benchmark），均未跑，不能作为已验证优质替代。SegFormer模型卡非商业研究/教育用途，应与代码许可分开核实。日志 `/tmp/portrait-parsing-night-expanded.log`、`/tmp/portrait-parsing-couple-expanded.log`、`/tmp/portrait-parsing-couple-crop14.log`。

以下为前轮历史记录：

最新进度（2026-10-06，分割离线试跑 / `9428549`）：用户授权尝试 SegFace/FaRL，新增独立 `scripts/face-parsing/` 评估工具与锁定环境清单。对20261005.jpg双脸运行 SegFace Swin-B/512、MobileNet/512、FaRL CelebM/448，均成功。原图6240×4160；baseline为现有host在2048px预览生成的覆盖，映射到源图的人脸方形裁切；Swin/MobileNet使用ImageNet归一化，完整checkpoint严格加载；FaRL采用官方RetinaFace、对齐和warp。原始19类输出及比较图、源/权重哈希在 `/Users/xiaoman/Developer/assets/face-parsing-trial/comparison/`；源哈希未变。模型与代码下载，照片仅本机处理。

视觉观察（非人工标注精度评测）：学习模型的额头/发际线覆盖比现有启发式更连续，能单独标记眼镜；MobileNet在人脸1手边纸巾附近产生皮肤小块误选。三者仍无胡须独立类别，镜片整体作为眼镜保护将同时排除镜片后的可见皮肤。FaRL边界较平滑，但尚不能凭两张脸断言胜过Swin。CPU四线程单次前向：Swin两脸0.810/0.732秒，MobileNet0.329/0.313秒；FaRL含检测1.812/1.648秒。不同对齐路径、不同输入、未测稳态，不能作为架构公平排名或手机速度。

输出检查：三个模型各两脸、类ID0–18、2400×550比较图和源文件保持断言通过，脚本语法检查及两张图目视检查通过。本轮仅实验脚本/文档，未改Swift源或应用；未重跑Swift49项、未验证CoreML/ANE、未改变已存coverage或processVersion。复现命令与upstream提交见脚本README，运行日志 `/tmp/portrait-parsing-evaluate.log`。输出图：品红=皮肤+鼻子，青色=眼镜，金色=头发；不是应用实际修改像素。下一步用更多实片及人工标注验证Swin/FaRL，并测试CoreML转换再决定接入；T3/T8均未认领。远端同步继续按用户要求跳过。

以下为前轮历史记录：

最新进度（2026-10-06，比较方式 / `e44f819`）：按用户本轮要求，原生细节窗口新增「分割滑动」「修改区域」「差值 ×4」，保留「并排」，默认分割。左侧原图、右侧已批准效果，拖动位置支持0–100%，无障碍调整每次5%。修改区域以品红叠加标出 canonical RGBA8 中任何改变的像素（零阈值），显示当前区域改变像素数；差值为逐通道绝对差、显示放大4倍，黑色为未改变。仅用于检查，不进入文档渲染和导出；没有修改磨皮参数、模型格式或 processVersion。

Debug/Release各49项（16 Core / 18 Render / 2 Analysis / 13 MCP）通过；新增比较回归覆盖相同图零变化、1字节差异也标记、差值增益、源数据保持、尺寸/增益拒绝。iOS arm64编译通过，UI import仅在PortraitMac，既有skin指纹通过。日志 `/tmp/portrait-comparison-debug.log`、`/tmp/portrait-comparison-release.log`、`/tmp/portrait-comparison-ios.log`。

独立测试app使用20261005.jpg的临时副本，生成0.65/0.30候选→批准→原生人脸检查→修改区域和差值截图检查→分割拖动，AX位置从50%变25%，调整动作也验证55%。人脸1当前裁切845480像素，364683像素有改动；这是此图此参数实际差异，不能当质量或覆盖保证。测试会话退出时放弃保存，未改用户源照片或编辑文件。最终小改动将初始人脸选择放入初始化，避免开窗先计算整图再切人脸；最终代码已重跑两种配置测试并构建，完整UI流程在此前仅差这一初始化的版本上验证。

应用已更新 `/Users/xiaoman/Developer/assets/PortraitPrototype.app`，重启生效。大图比较按区域生成两张诊断图，内存仍较高；切换区域会丢弃旧结果，但已开始的诊断计算尚不支持内部取消。细节仅显示已批准结果；未批准候选不参与。T3未认领，下一队列任务仍是斑点检测。按用户要求暂不远端同步。

以下为前轮历史记录：

最新进度（2026-10-06，T2 / `334c224`）：并发挂起已定位并修复。恢复 MCP suite 并发后复现，sample 显示8个 cooperative 工作线程阻塞在 Vision 同步 perform（FaceAnalyzer.swift:58），等待 VNControlledCapacityTasksQueue；这次挂起不是票据耗尽或 NSFileCoordinator。PortraitSession 现使用每会话独立串行 GCD SerialExecutor，把阻塞框架处理移出 cooperative pool，保持 actor 隔离和同步提交不重入。未修改图像算法、模型格式或 processVersion。

已去掉 MCPTests 的 serialized；新增16独立会话并发 Vision、批准/保存、重开像素一致与撤销回归。Debug、Release各46项（16 Core / 15 Render / 2 Analysis / 13 MCP）通过，iOS arm64编译通过，核心target零AppKit/UIKit，既有skin指纹通过。并发回归 Debug 0.308秒 / Release 0.322秒，包含全部会话流程，不是单张渲染性能。没有加超时或重试。

复现证据 `/tmp/portrait-t2-before-sample.txt`；修复验证命令为 `swift test --package-path PortraitFoundation --scratch-path /tmp/portrait-t2-debug`、Release加`-c release`、iOS使用任务书指定triple/sdk。日志分别 `/tmp/portrait-t2-debug.log`、`/tmp/portrait-t2-release.log`、`/tmp/portrait-t2-ios.log`。裸FaceAnalyzer同步API仍要求调用方选择适合阻塞操作的执行上下文；本轮修复覆盖全部PortraitSession入口。应用已更新，重启生效。本轮没有重新自动操作UI，事务/取消等既有回归保持通过。用户要求暂不远端同步；下一条是 T3 斑点检测，尚未认领。

以下为前轮历史记录：

最新进度（2026-10-06，T1 / `b25f38a`）：裸 SwiftPM 启动已修复，PortraitAppDelegate 初始化时设置 regular 激活策略，启动完成激活窗口；仅修改代理，不修改窗口内容或增加打包脚本。可复现：`PORTRAIT_STARTUP_DIAGNOSTICS=1 swift run -c release --package-path PortraitFoundation portrait-mac`，诊断记录 `visibleWindows=1; titles=["人像修图 · 原型"]`。osascript 验证因系统辅助访问权限拒绝未执行成功；应用自身诊断代替窗口计数，bundle 使用 CUA 独立核查1个窗口。

最终代码 Debug 与 Release 各45项通过；iOS arm64编译通过；三个核心 target 零 AppKit/UIKit；未改渲染算法，指纹测试保持通过。bundle 用真实照片生成候选→退出确认→取消退出保留候选实测通过。应用已更新 `/Users/xiaoman/Developer/assets/PortraitPrototype.app`。下一条为 T2 并发等待根因；当前仍保留 serialized，未在T1中改动。按用户既有要求暂不 fetch/push。

以下保留前轮历史记录：

最新进度（2026-10-06）：全尺寸导出和原生细节检查增加真实阶段提示（核对源、读取像素、准备覆盖、渲染、PNG 编码、写入），Mac 提供取消处理按钮；保存、批准、撤销不开放取消。Task 取消在阶段边界检查，未完成的导出不写入目标文件，已批准状态保持不变。单次渲染和 ImageIO 编码尚不支持内部中断，点击取消可能需要等待当前阶段结束；已完成文件写入不会被当作取消撤回。没有伪百分比。

Release 构建与 45 项测试通过（16 Core / 15 Render / 2 Analysis / 12 MCP）。新增预取消检查及扩展 nativeExport 验证阶段回调中取消后抛 CancellationError、没有输出文件、revision 不变。本轮未重新执行真实全尺寸导出，也未自动点击真实 UI 取消按钮；阶段/取消语义由协议外会话回归验证。更新应用在 `/Users/xiaoman/Developer/assets/PortraitPrototype.app`，重启生效；远端同步继续跳过。

当前限制：阶段内不可立即取消；PNG ≤40MP，无 EXIF，内存较高；脸部检查只显示已批准效果，未批准候选原生检查待做；撤销不跨重启，AI 客户端批准桥接和移动端 UI 未完成。下一步建议打通 AI 候选到原生批准界面，保留三工具表面和绑定票据的事务规则。

> 工作文档。每次开工先看这里，收工前更新这里。
>
> 最后更新：2026-10-05（核查本地 `c936dc4`；远端 fetch 因 SSH 主机验证失败未完成）

本次更新：已读取另一工具的最新提交与协作看板。基础修图、分析和三工具 MCP 原型已在 `f18bc08` 提交；第二张双人实片验证记录见 `08c4404`；`8ba0f0e` 已将候选统一为保守 0.35/0.60、标准 0.65/0.30（用户选定）、强 0.75/0.12。本轮为源码与文档交叉核查，未重跑历史已验证的 40 项测试或实片测量。原生批准 UI、完整分辨率导出及祛瑕疵仍未完成。

---

## 一、这是什么

**目标**：一套自用的人像修图软件，替代现在的 **PS + 像素蛋糕** 工作流。三端（Mac / iPad / iPhone），并且**让 AI 能直接控制它**。

**起点**：fork 了 [Compositor](https://github.com/robbietilton/Compositor)（MIT，macOS 图像编辑器，36k 行 Swift + C）作为像素引擎的参照与来源。

**当前状态一句话**：**数据模型、基础修图、人脸分析和 MCP 原型已验证；新应用原生 UI 尚未开始。**

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
| **PortraitFoundation 数据模型** | ✅ 完成 | 16 测试全绿；整个包现有 3686 行 Swift / **40 测试** |
| i18n 工具链 | ✅ 完成 | `scripts/i18n/` |
| **CompositorKit 抽取** | ❌ 未开始 | Phase 0 的核心动作 |
| **RetouchRenderer 实现** | 🟡 基础栈完成 | skin + tone / presence / whiteBalance / 点曲线；完整算子与大图导出待做 |
| **新 App（UI/外壳）** | ❌ 未开始 | 一行都没有 |
| MCP server | 🟡 原型完成 | 三个工具、stdio、预览票据和事务；真实客户端 UI/HTTP 未接入 |
| 人脸检测 / 压感 | 🟡 / ❌ | Vision + 启发式遮罩已做；**遮罩仅限人脸矩形**（脖子/胸口/眼下/鼻梁不在内，见 4.9）；压感未开始 |

---

## 四、已完成

### 4.1 仓库与分支

```
origin    https://github.com/EvilBT/Compositor.git        ← 你的 fork
upstream  https://github.com/robbietilton/Compositor.git  ← 原作者，保留参照

main                 11d8d7a  ← 上游，从未改动
portrait-foundation  3cec931  ← skin 及独立复核已提交；本次分析/MCP 改动尚未提交
```

`b0cd3da` 相对 `main`：54 个文件改动，+12835 / −127 行；不含本次工作区改动。

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

跨平台人像修图的**声明式修饰模型**。`Sources/PortraitCore/`，当前 1332 行。

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

### 4.6 skin 参考渲染器（本次工作区改动）

- 新增独立 `RetouchKit` 库，不依赖 Compositor UI；只实现 `skin`。
- `processVersion` 1 为基础频率重建，2 增强纹理保留并限制结构边缘的低频改动。新文档默认 2，缺失版本字段永久回退到 1。
- 整栈绑定文档版本；独立单步折叠使用同版 context，输出逐字节一致，容差 0。两个版本均有固定图片输出指纹守护。
- 显式皮肤遮罩、遮罩扩张/收缩、透明度保护、零强度、预览半径缩放和错误处理已验证。纹理全保留时仍能改善低频明暗不均。
- 无检测结果且无遮罩时保护模式保持原图；已有人脸却无遮罩时报错，不把人脸框冒充皮肤区域。
- 当前合成纹理样本：texture 0.85 时 v1 保留 72.73%、v2 保留 85.25%；texture 0.10 时分别 1.23%、10.17%，均通过 ≥60% / ≤25% 阈值。
- 新增 10 个渲染测试（其中 3 个各测两版），加原模型 16 项全部通过。macOS Debug / Release 测试与 iOS arm64 编译通过；CI 已配置 Debug 测试及 iOS 编译，远端结果未验证。
- 限制：RGBA8、编码 sRGB 的 CPU 参考路径，默认最多 16MP。自动皮肤/瑕疵检测未实现，非零 `blemishStrength` 及其他已知算子明确报错。真实人像、跨设备像素一致性与大图性能待验证。

### 4.7 对 4.6 的独立复核（本次会话，实测）

4.6 是作者自己的总结。以下是我逐条验证后的结果。

**验证通过**（不是转述，是实际跑过）：

| 声明 | 验证方式 | 结果 |
|---|---|---|
| 26 个测试全过 | `swift test` + `swift test -c release` | ✅ Debug 与 Release 都过 |
| 指纹在两种配置下一致 | 上面两次运行 | ✅ 浮点确定性成立 |
| iOS 能编译 | `swift build --triple arm64-apple-ios18.0` | ✅ 3.9 秒 |
| 像素路径不含平台 UI | `grep -rn 'import AppKit\|UIKit\|Cocoa' Sources/` | ✅ 零命中 |
| 整栈绑定文档版本 | 读 `SkinRendererTests.stackParity` | ✅ 它故意传**错误的** context 版本再断言相等 |
| 缺失 `processVersion` 走 v1 | 读 `versionSemantics` + 跑 | ✅ 而且**它修掉了我写的一个真 bug**，见下 |
| 算法在真实图像上有效 | 用测试人像跑 v1/v2 × texture 0.85/0.10/0，读图 | ✅ 见下 |

**它修掉了我写的一个真 bug。** 我原来的解码器是：

```swift
processVersion = try c.decodeIfPresent(Int.self, forKey: .processVersion)
                 ?? Self.currentProcessVersion     // ← 错
```

`currentProcessVersion` 一旦升到 2，**所有不含该字段的旧文档都会静默改用 v2 渲染**——外观全变，而这正是规则 1 存在的意义。正确写法是 `?? 1`（缺失即原始语义，永久）。这是规则 1 的反面教材被我写进了代码，他们抓到了。

**首次真实图像验证**（1200×1600 合成人像，含毛孔与瑕疵）：

- `texturePreservation = 0.85`：毛孔保留良好、色块均匀 → 可用
- 降到 `0.10` / `0`：逐步趋近塑料，瑕疵变成软团
- v2 在同一设置下保留比 v1 多（`sqrt` 设计如此）
- **结论：算法是对的。**

**真实性能，以及一个我自己踩的坑**：

| | Debug | Release |
|---|---:|---:|
| 原始 `box` | 18,695 ms | **503 ms** |
| 修改后 `box` | 5,058 ms | **372 ms** |

我最初报出的是 **Debug** 数字（18.7 秒），**那是错的**——`swift build` 默认 `-Onone`。真实值是 **503 ms / 1.9 MP**，外推 12MP ≈ 3.2 秒、24MP ≈ 6.3 秒；预览路径先缩到 ~2048px，约 160 ms，可用于实时预览。

顺带查明：`box(_:)` 里的**捕获式局部函数 `index()` 阻止了泛型特化**，`Range<Int>` 迭代因此退化为 `Collection._failEarlyRangeCheck` → `_swift_getGenericMetadata`，**每次迭代查一次元数据缓存**。我用不安全缓冲 + `while` 循环重写，**算术逐位不变**（指纹测试证明），Release 1.35×、Debug 3.7×（后者让测试套件从 1.6 s 降到 0.45 s）。改动在 `Sources/RetouchKit/SkinRenderer.swift`，注释里记了实测数字。

**4.6 没有提到、但更重要的一条**：

`renderStep` 对 `skin` 以外的任何算子都抛 `unsupportedOperation`，而 `renderStack` 折叠**全部**启用算子。所以**一个含 `tone` 的真实文档根本渲染不出来**——不是磨皮效果差，是整条栈直接报错。这是当前最大的实用性障碍。

---

### 4.8 用户真实人像、基础渲染与 MCP（本次工作区改动）

**输入**：`/Users/xiaoman/Developer/assets/0229_95_1.jpg`，7008×4672（约 32.7MP）。这是用户提供的实片，与 4.7 的合成测试图不同。照片和生成产物均在仓库外。

**1a 已完成参考路径**：新增 `PortraitAnalysis`，Vision rectangle/landmarks revision 3；EXIF 先归正，再统一转左上坐标。人脸轮廓和眼/眉/嘴几何保护 + 脸颊自适应色度先验生成保守覆盖。检测到 1 张脸，亮度标准差约 0.0975，覆盖约 0.380。不是神经皮肤分割；亮片/毛发/遮挡仍需人工看图，祛瑕疵未实现，`blemishFraction` 不可当测量值使用。

**1b 已完成基础栈**：新增 `PortraitRenderer`，支持 `skin`、`tone`、`presence`、相对 `whiteBalance` 和点 `toneCurve`。其他启用的已知算子、参数曲线、refine saturation 明确报错。曝光使用线性 sRGB，其余调节是参考近似，不是 Photoshop 精确复刻。旧 skin 两版指纹仍通过，develop+skin 与独立逐步折叠完全一致。

**2 已完成 headless 原型**：`PortraitMCP.MCPServer` 和 `portrait-mcp` 同进程拥有会话、分析与渲染；stdio 只暴露 `analyze_faces` / `render_preview_with` / `set_stack`。预览返回 JPEG 与候选票据、不落盘；确认需匹配票据、完整栈及 revision。应用记录 AI 归属；宿主 undo 恢复整份前态。可选 JSON 侧车原子保存，精确覆盖作为分析缓存保存；源哈希验证与协调写入防外部覆盖。撤销历史不跨重启；缓存缺失/损坏后重新检测，不保证历史逐像素一致。

**实际测试结果**：

- 40 个测试声明：模型 16、渲染 15、分析 2、MCP/事务 7；Debug / Release 都通过。原 skin 指纹不变，iOS arm64 编译通过。
- `scripts/test-portrait-mcp.py` 驱动真实 stdio 进程及这张照片：3 个工具可列出、人脸分析成功、图片内容可解码、未确认请求拒绝、临时确认写入保存、重复请求拒绝。**确认是测试模拟，临时文件自动删除，未创建永久用户编辑**。
- 单元测试验证撤销、保存重开、写失败不改内存、外部文件变动不被覆盖。CI 已增加 Release 检查，远端尚未运行。
- 源图 SHA-256 在测试前后相同。首轮校准已写入 `SKILL-portrait-retouch.md`，只适用于这一张样本，未泛化。

**原生分辨率脸部特写（892×892）**：

| 候选 | strength / texture | 高频能量保留 | 零覆盖区域改动像素 |
|---|---|---:|---:|
| 保守 | 0.30 / 0.85 | 96.3% | 0 |
| 标准 | 0.50 / 0.70 | 85.4% | 0 |
| 强 | 0.65 / 0.55 | 70.6% | 0 |

radius 均为 12 原始像素。用高覆盖区红通道离散拉普拉斯测量，不能与不同强度/度量的历史实验直接等同。目视特写保守档更适合保留本片妆容、装饰与细纹理；最终审美尚待用户反馈。

**产物**：`/Users/xiaoman/Developer/assets/portrait-review/`，含整图预览、覆盖叠加、四列脸部对比、三档候选、统计及 MCP 验证报告。列顺序是原图 / 保守 / 标准 / 强。可运行 `scripts/portrait-mcp.sh` 启动；完整限制和配置见 `PortraitFoundation/PROTOTYPE.md`。

**仍未完成**：原生批准/撤销界面、接入现有 Compositor App、具体 AI 客户端配置与真人确认、HTTP、真实 32.7MP 整图导出、语义皮肤分割、祛瑕疵、多样本/跨设备质量验证。当前是预览与原生局部测试原型。

### 4.9 对 4.8 的第三轮独立复核（本次会话，实测 + 看图）

**先说结论：工程部分全部成立，我逐条验证了。但这一轮暴露出——现在卡住产品的不是架构，是"这张样本答不了审美问题"。**

**验证通过：**

| 声明 | 验证方式 | 结果 |
|---|---|---|
| 40 个测试（16/15/2/7） | `swift test` + `-c release` | ✅ 两种配置 |
| iOS 编译 | `--triple arm64-apple-ios18.0` | ✅ 含 MCP 可执行文件 |
| 三张候选的实测数字 | 读 `face-metrics.json` | ✅ 96.308% / 85.429% / 70.650%，与 4.8 完全一致 |
| 零覆盖像素未改动 | 同上 | ✅ 三次都是 `protectedPixelsChanged: 0` |
| 人脸数与统计 | 读 `analysis.json` | ✅ 1 张脸、覆盖 0.3795、亮度标准差 0.0975 |
| 渲染器只支持声明的算子 | 读 `PortraitRenderer` | ✅ 其余抛 `unsupportedOperation`，参数曲线与 refine saturation 显式拒绝 |
| skin 指纹未被改动 | `git diff` + 测试 | ✅ 仅把 `blur` 从 private 改为 internal 供 `PortraitRenderer` 复用 |
| **MCP 端到端可用** | **我自己写的客户端**，非他们的脚本 | ✅ **16/16** |

我自己那个客户端验证了：版本协商、恰好 3 个工具、`analyze_faces` 返回文本 + 图片、
`render_preview_with` 返回 JPEG + ticket + canonical stack、未确认写入被拒、确认后写入且 sidecar 落盘、
**同一 ticket 重放被拒**。

**看的图（这是 4.8 里没有的信息）：**

我看了 `face-comparison.png`（真脸四列）、`face-mask.png`（遮罩本身）、`mask-overlay.png`（整图叠加）。

1. **遮罩的保护是对的。** 四列里眼睛、眉毛、嘴唇、头发、泪钻高光**完全没被碰过**，只有皮肤在变。
   这正是启发式遮罩最容易出错的地方，而它做对了。
2. **但遮罩是"人脸矩形"限定的，只覆盖脸部椭圆。** 叠加图里脖子、胸口、前臂同样是皮肤，
   **全部在覆盖之外**。对修图师来说脖子和胸口的肤色衔接是常规工作。这是**结构性限制，
   不是样本问题**——再多样本也不会改变它。他们第六节第 2 条"覆盖修正"已经提到了这一点。
3. **眼窝整片被排除**（含眼下），**鼻梁/鼻头有暗块**。眼下是修图师最常处理的位置之一（黑眼圈），
   鼻子是毛孔最明显的地方。目前这两处不参与磨皮。
4. **这张照片答不了"哪个候选更好"这个问题。** 夜拍、浓妆、泪钻、彩色美瞳，
   人物只占画面约 15%（脸宽 ~360px / 7008px）。脸本来就无纹理可磨，
   三列差异因此很微妙。**用这张样本让用户回答偏好，得到的证据很弱。**

**发现的可用性缺陷**（不影响正确性，但 agent 会踩）：

`session_id` **必须是 UUID，但 tool schema 只写了 `string`**。我按 schema 发 `"s1"`，
服务端 `UUID(uuidString:)` 解析失败，抛出的是 **`previewMismatch`**——错误名指向"栈不匹配"，
完全误导。**任何 agent 第一次调用都会撞上。** 修法：schema 加 `format: uuid`，并抛专用错误。

**我无法验证的**：他们自己的 `scripts/test-portrait-mcp.py` 断言 `len(faces) > 0`，
所以**必须先有真实人像**才能当冒烟测试跑；我给合成人像时它在第 3 步正确退出。
脚本因此不能作为通用回归测试。

### 4.11 用户已确认的决策与协作机制（本次会话）

**用户拍板（不要再问第二遍）：**

| 决策 | 值 |
|---|---|
| **男性人像的标准档** | **`strength 0.65` / `texturePreservation 0.30`** |
| 理由 | 男性磨皮过度不自然；0.30 是下限，再低（0.10 / 0.00）就过了 |
| **强度应区分性别** | 用户明确要求，**可以后实现** |

这条与 `SKILL-portrait-retouch.md` 原有的「`texturePreservation` 低于 0.45 会出塑料脸」冲突——
那个 0.45 是从一张浓妆女性照片推出来的，**不是普适阈值**。已在 SKILL 里改正，并把决策表
标注为「上限而非目标」、补上性别维度缺失的说明。

**协作机制（本轮新增）：**

因为**两个 AI 同时在这个仓库上工作**，新增 `SYNC.md` 作为协作看板，并在两份 `AGENTS.md`
顶部加了强提示。四条硬规则：开工前 `fetch` 并读看板；**动手前登记要碰的文件**；
频繁 push；收工前更新看板。

`SYNC.md` 的作用是**防覆盖**，与 `STATUS.md`（长叙事历史）分工不同，因此刻意保持短。

### 4.10 第二张实片验证（本次会话，`20261005.jpg`）

用户提供了第二张照片：6240×4160（26MP），**检测到 2 张脸**，review 4.6 秒跑完。

**验证结果：**

| 项 | 结果 |
|---|---|
| 度量可复现 | ✅ 工具报 96.9636 / 87.0025 / 73.0124，**我按其方法独立复现出 96.964 / 87.003 / 73.012，完全一致** |
| 零覆盖像素 | ✅ 三次都是 0 |
| 硬案例：眼镜 | ✅ **眼镜框被干净排除**，四档里镜框、镜片、反光完全没被碰过 |
| 头发 / 胡子 / 眼睛 / 嘴唇 | ✅ 全部保留 |
| 全强度范围可用 | ✅ texture 推到 0 时磨皮很重，但五官、眼镜、胡子、身份全部保留，没有崩 |

**这张照片暴露的四个问题：**

1. **三个候选只覆盖了工具范围最温和的一段。** 它们是 texture 0.85 / 0.70 / 0.55，
   而参数可以到 0。我按 strength 0.65 把 texture 推到 0.30 / 0.10 / 0.00 后，
   差异**一眼可见且都还能用**。用现在这三档问用户"哪个好"，用户很难有明确意见。
   **建议重新居中候选，例如 0.30/0.80、0.50/0.50、0.65/0.20。**

2. **瑕疵在任何强度下都不消失。** 下巴和脸颊的红点在 texture 0.00 时依然可见。
   `blemishStrength` 未实现——而**祛瑕疵是这张照片最明显的修图需求**。
   磨皮只解决"纹理"，不解决"斑点"。这是当前最大的能力缺口。

3. **覆盖仍限于人脸椭圆。** 这张是双人场景，**两人的脖子、胸口、耳朵全部在覆盖之外**（叠加图里看得很清楚）；
   男性持纸巾的手也没被覆盖（正确）。脖子与胸口的肤色衔接是修图常规工作，**这是结构性限制**。

4. **又两个 schema 缺口**（和 4.9 的 `session_id` 同类）：`max_size` 实际限定 **64...2048**，
   schema 只写 `integer`；越界抛 `invalidSize`，不说是多少。**agent 只能靠试。**

**仍未改变的**：这张照片虽然比 4.9 那张合适得多（自然光、裸肤、脸占满画面、可见毛孔），
但它仍是**夜间活动现场照**——他人手持相机、双人、背景有台阶和暖光。
判断审美偏好比上一张强得多，但如果要定"这就是标准档"，仍建议一张**日光、单人、正面**的。

---

**关于他们的自我报告**：`PROTOTYPE.md` 的诚实度罕见——明确写了"`confirmed: true` 是客户端断言，
不是同意的证明"、"`luminanceStdDev` 包含光照和妆容，不只是毛孔"、"这是启发式遮罩，
不是神经网络分割"。**这种自我报告应该被鼓励**，它让复核能聚焦在真正未知的地方。

---

## 五、未完成

### 5.1 阻塞性的（不做就没法继续）

| # | 事项 | 为什么阻塞 |
|---|---|---|
| 1 | **按需抽取 `CompositorKit`** | 画笔等旧引擎能力需要与 UI 分离；独立 skin 参考实现不依赖这一步 |
| 2 | **完善皮肤覆盖与全图导出** | 保守覆盖和基础栈已存在；语义分割、祛瑕疵及 32.7MP 整图导出未落地 |
| 3 | **新 App 外壳** | 没有 UI，什么都看不到 |

### 5.2 功能性的（按人像工作流排序）

| # | 事项 | 优先级 | 说明 |
|---|---|---|---|
| 1 | **数位板压感 / 倾斜** | 🔴 最高 | Compositor 完全没有。专业修图的地基。**iPad + Apple Pencil 免费给** |
| 2 | **人脸检测 + 关键点** | 🟡 基础完成 | Vision 与保守皮肤覆盖已做；多人身份跟踪及语义分割待做 |
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

### 当前依赖顺序（别并行）

1. **候选档位重新居中已完成**：`8ba0f0e` 将两处列表合并为 `PortraitHost.reviewCandidates`；当前为 0.35/0.60、0.65/0.30、0.75/0.12。男性标准档已由用户选定，不再重复询问。提交记录报告第二张实片能量保留约 87.8/54.2/30.4%；本轮未重新测量。
2. **最小原生批准/撤销界面**：真人确认 UI 和具体 AI 客户端尚未接入；`confirmed` 字段是客户端声明。先确定首个客户端平台，再登记文件范围实现。也可先处理 `session_id` 的 UUID schema 和误导性错误这一小范围缺口。
3. **完整分辨率输出与覆盖修正**：现有宿主仅导出 ≤2048px 整图预览和原生脸部特写，不能把 32.7MP 样本当作已支持整图成片导出。
4. **扩大样本、继续校准方法**：当前亮度标准差受光照/妆容影响，不能直接推强磨皮。增加不同肤色、光照、角度和遮挡样本后再调整通用建议。
5. **祛瑕疵是本轮最大的能力缺口**：`blemishStrength` 未实现，红点在最强档下也不消失（4.10）。
   磨皮只解决"纹理"，不解决"斑点"——而斑点才是这张照片里最显眼的修图需求。
6. **覆盖范围**：脖子 / 胸口 / 耳朵不在遮罩内（4.9、4.10 两次都确认）。结构性限制，
   真实工作流里会明显受限。
7. **其余算子和宿主能力**：液化、眼牙、光影、压感、HTTP 与三端 UI 仍未实现；按真实工作流依赖推进。

### 本轮已完成的原计划

- `skin` 与版本/零容差契约：已完成并复核。
- 1a Vision 检测、关键点与保守皮肤覆盖：已在用户真实照片上验证。
- 1b tone / presence / 点曲线（另含相对白平衡）：已实现并测试。
- 2 三个 MCP 工具与 stdio：通信/预览/事务已验证，真人批准界面仍欠缺。
- 3 方法论校准：首张实片记录已加入，尚未形成跨样本结论。

### 关于那些数字

第 1 步的量化验收标准（`texturePreservation = 0.85` 时高频能量 ≥ 60%，`= 0.10` 时 ≤ 25%）**已在两版上通过**。但要注意 **4.7 记录的实测值（真实人像 88%/50%）与单元测试夹具（72%/1.2%）不可比**——两者用的高频度量不同（我的 FFT σ=9 高通 vs 测试的离散拉普拉斯），内核也不同。**以单元测试的指标为准**，它才是被指纹钉住的那个。

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

## 九、当前结论

**已有可处理真实照片的 headless 原型，并完成两张实片验证；尚未形成可交付的原生修图应用。**

下一步重点是原生批准/撤销、完整分辨率输出和祛瑕疵。交叉开发以 `SYNC.md` 登记文件范围、提交哈希及验证依据；历史测试结果与本轮核查分开记录。当前远端同步被 SSH 主机验证失败阻断，不能把本地最新视为远端最新。


### SAM 3 / 3.1 纳入比较（2026-10-06）

用户要求已登记为独立候选，比较方案见 `scripts/face-parsing/sam3-comparison.md`。核实官方3.1为Object Multiplex视频追踪权重，图片builder仍默认SAM3；不可把SAM3图片输出标成3.1。两官方HF仓库gated=manual，匿名权重HEAD均401，因此本轮没有取得权重、没有推理效果或CPU/MPS性能结论。固定两张本地照片、文字/示例/相同12探针、无饰物负例、保护核心与皮肤外零变化检查已列入方案。下一步需获准的本地权重，再验证加载完整性和本机兼容性。本轮仅文档及官方资源可用性检查，未改Swift/App，未重跑Swift测试；远端同步继续按用户要求跳过。


### HF优化SAM候选调研（2026-10-06）

已查发布方模型卡、LiteText论文和HF API。MLX社区sam3-bf16/sam3.1-bf16/sam3-8bit均ungated，匿名权重HEAD200，纠正上一轮仅官方权重导致的访问阻碍：可走社区Apple Silicon转换途径，但尚未下载/推理/核实转换一致性。优先同MLX运行时SAM3与3.1，再测8bit内存与小目标退化；EfficientSAM3/LiteText为轻量化候选，不是贴钻精度冠军。CoreML3.1候选仅backbone+tracker；Embedl偏TensorRT且发布方cgF1较自身FP32下降。模型清单、修订及限制已写sam3-comparison.md。未改Swift/App，未运行Swift测试，本轮只资料和可用性检查。


### MLX SAM3/3.1/8bit实测（2026-10-06）

两图六提示、局部/示例框及3.1转BF16共57输出审核，源哈希/crop/权重SHA保持。3.1名bf16实际F32，峰值5.612GB，转BF16为3.897；SAM3 BF16为3.870、8bit3.222GB。后续11调用中位3.623/3.607/3.987/3.705秒，仅单次探索。整脸glitter SAM3/8bit为空，3.1仅456像素；固定局部三者找到亮片，无3.1明显优势或精度排名。男脸饰物负例均空且眼镜识别。mlx-vlm0.7.6的3.1 detector忽略boxes，一份示例框已标无效，不评价官方示例能力。完整报告/对比图assets/face-parsing-trial/mlx-results.md。下一步自动ROI、更多标注/负例、几何提示支持，再组合保护羽化。未改Swift/App，未重跑Swift测试，原照片未上传或改动。


### 自动局部语义保护优化（2026-10-06）

离线流程新增关键点驱动左右脸颊/额头/下半脸ROI，FaRL皮肤+脸框约束、实例皮肤占比/面积拒绝、两种提示交集确认、跨区域union及核心锁定/羽化。同ROI四提示共享编码；两模型各一次cached/独立推理mask/score/box精确一致。两图3脸，SAM3及3.1转BF16共120提示预测、48真实v2渲染、5项新Python回归通过。保守核心装饰脸11710/12682像素；普通两脸宽松133/189及194/240变0。所有optimized核心和全部皮肤外实际改动0；无core时与baseline两档逐像素同。源哈希/crop保持。仍漏亮片、连带部分邻近皮肤，两提示相关、无精度排名，3.1几何提示未修。5ROI/4提示约24–30秒/脸，仅单次探索。完整报告assets/face-parsing-trial/mlx-protection-results.md。未改Swift/App/保存版本，未重跑Swift套件；临时Release渲染harness已清理，环境/权重保留。下一步会话分析缓存、更多标注/负例和可修正App实验入口。
