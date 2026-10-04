# -*- coding: utf-8 -*-
"""zh-Hans for the prose, part two. See prose.py for the conventions."""

ZH_PROSE2 = {
    # ---- dialogs and errors ----
    "Compositor will convert these Photoshop features. Nothing is applied until you continue.":
        "Compositor 将转换以下 Photoshop 特性。在你继续之前不会应用任何更改。",
    "Reading the file to see what needs converting.": "正在读取文件，以确定需要转换的内容。",
    "Import couldn’t finish": "导入未能完成",
    "Couldn’t crop": "无法裁剪",
    "Couldn’t paint": "无法绘画",
    "Unsaved changes": "未保存的更改",
    "Save Project": "存储项目",
    "Save Project As": "项目存储为",
    "Don’t Save": "不存储",
    "Keep Mine": "保留我的",
    "Open one project at a time": "一次只能打开一个项目",
    "Couldn’t open the project": "无法打开项目",
    "Couldn’t save the project": "无法存储项目",
    "Couldn’t export PNG": "无法导出 PNG",
    "Couldn’t export JPEG": "无法导出 JPEG",
    "Couldn’t resize the image": "无法调整图像大小",
    "Couldn’t change canvas size": "无法更改画布大小",
    "Couldn’t trim image": "无法裁切图像",
    "Missing source": "源文件丢失",
    "Create a canvas or import an image.": "新建一个画布，或导入一张图像。",
    "Import an image or add a blank layer.": "导入一张图像，或添加一个空白图层。",
    "Create canvas": "新建画布",
    "New canvas": "新建画布",
    "Drop into new canvas": "拖入可新建画布",
    "Drop to open in a new canvas": "拖放可新建画布并打开",
    "Open project": "打开项目",
    "Import Images": "导入图像",
    "Import Photoshop File": "导入 Photoshop 文件",
    "Copy Layers from Project": "从项目拷贝图层",
    "Import Image": "导入图像",
    "Importing images…": "正在导入图像…",

    # ---- canvas and image size ----
    "Only print dimensions and resolution change. Pixels stay unchanged.":
        "只有打印尺寸与分辨率改变，像素保持不变。",
    "Relative to current dimensions": "相对于当前尺寸",
    "Resizes layer pixels and applies existing transforms. Undo restores the originals.":
        "调整图层像素大小并应用已有的变换。撤销可恢复原状。",
    "Resample": "重新取样",
    "Use 1–%@ pixels per side, up to %lld megapixels, and 1–9,600 pixels/inch.":
        "每边 1–%@ 像素，总计不超过 %lld 百万像素，分辨率 1–9,600 像素/英寸。",
    "Final dimensions must be 1–%@ pixels per side.": "最终尺寸每边必须为 1–%@ 像素。",
    "Enter a whole number from 1 to %lld px.": "请输入 1 到 %lld 之间的整数像素值。",
    "Enter whole numbers from 1 to %@ pixels.": "请输入 1 到 %@ 之间的整数像素值。",
    "Result: %lld × %lld pixels": "结果：%lld × %lld 像素",
    "Preset sizes": "预设尺寸",
    "Preset sizes for screens and common formats": "屏幕与常用格式的预设尺寸",
    "Trim": "裁切",
    "Trim Away": "裁切掉",
    "Transparent Pixels": "透明像素",
    "Background for transparency": "透明区域的背景色",
    "Color for the added canvas": "新增画布区域的颜色",
    "Canvas Extension": "画布扩展",
    "Extension color": "扩展区域颜色",
    "Canvas Size": "画布大小",

    # ---- layers, masks, effects ----
    "Add layer mask": "添加图层蒙版",
    "Add layer mask (Option-click for a black mask)":
        "添加图层蒙版（按住 Option 单击可添加黑色蒙版）",
    "Add layer mask revealing the selection (Option-click to hide it)":
        "添加显示选区的图层蒙版（按住 Option 单击则隐藏选区）",
    "Add Hide-All Mask": "添加隐藏全部蒙版",
    "Add Reveal-All Mask": "添加显示全部蒙版",
    "Hide All (Black)": "全部隐藏（黑）",
    "Reveal All (White)": "全部显示（白）",
    "Delete Mask": "删除蒙版",
    "Delete layer mask": "删除图层蒙版",
    "Enable Mask": "启用蒙版",
    "Disable Mask": "停用蒙版",
    "Enable Layer Mask": "启用图层蒙版",
    "Disable Layer Mask": "停用图层蒙版",
    "Fill Mask": "填充蒙版",
    "Paint Mask": "绘制蒙版",
    "Gradient Mask": "渐变蒙版",
    "Copy Layer Mask": "拷贝图层蒙版",
    "Replace Layer Mask": "替换图层蒙版",
    "Link Mask": "链接蒙版",
    "Unlink Mask": "取消链接蒙版",
    "Link Layer Mask": "链接图层蒙版",
    "Unlink Layer Mask": "取消链接图层蒙版",
    "Transform Layer Mask": "变换图层蒙版",
    "Distort Layer Mask": "扭曲图层蒙版",
    "Show mask alone": "单独显示蒙版",
    "Stop viewing the mask": "停止查看蒙版",
    "Mask background": "蒙版背景",
    "Mask foreground": "蒙版前景",
    "Hide the background behind a layer mask, keeping the foreground subjects. The pixels stay, so the background can be painted back at any time.":
        "用图层蒙版隐藏背景、保留前景主体。像素仍在，随时可以把背景重新画回来。",
    "Layer Blend Mode": "图层混合模式",
    "Layer Opacity": "图层不透明度",
    "Layer Effects": "图层效果",
    "Duplicate / Layer via Copy": "复制 / 通过拷贝的图层",
    "Duplicate Layers": "复制多个图层",
    "Move Layer": "移动图层",
    "Move Layers": "移动多个图层",
    "Merge Down": "向下合并",
    "Merge Layers": "合并图层",
    "Merge Group": "合并组",
    "Reorder Layers": "重新排列图层",
    "Rename Layer": "重命名图层",
    "Create clipping mask": "创建剪贴蒙版",
    "Release clipping mask": "释放剪贴蒙版",
    "Toggle Clipping Mask": "切换剪贴蒙版",
    "Group Layers": "编组图层",
    "Expand or collapse folder": "展开或折叠文件夹",
    "Delete Selected Layers": "删除选中的多个图层",
    "Delete selected layers": "删除选中的多个图层",
    "Delete selected layer": "删除选中的图层",
    "Delete selected effect": "删除选中的效果",
    "Delete Guide": "删除参考线",
    "Move Guide": "移动参考线",
    "New Guide": "新建参考线",
    "Bake and Delete": "烘焙并删除",
    "Remove Links and Delete": "移除链接并删除",
    "Layer effects": "图层效果",
    "Layer effects: stroke and drop shadow": "图层效果：描边与投影",
    "Show the transform box and handles (⌘H). When hidden, drag anywhere to move the layer.":
        "显示变换框与控制点 (⌘H)。隐藏时，在任意位置拖动即可移动图层。",
    "Select layers by clicking the canvas. Hold Command to turn it the other way while you click.":
        "在画布上单击可选择图层。按住 Command 单击则反向选择。",

    # ---- guides, grid, snapping ----
    "Drag on the layer to place a guide. Draw at least two lines.":
        "在图层上拖动以放置参考线。至少画两条线。",
    "Draw two or more lines on the preview that should be level or vertical.":
        "在预览上画两条或更多应当水平或竖直的线。",
    "Draw the marks for the light tones on the dark color, like a glowing screen":
        "用暗色画出亮部标记，如同发光的屏幕",
    "Choose a custom grid color": "选取自定义网格颜色",
    "Use gridlines every %lld–%@ pixels and %lld–%lld subdivisions, no more than the pixels between gridlines.":
        "网格线间隔 %lld–%@ 像素，细分 %lld–%lld，且不超过网格线之间的像素数。",
    "A subdivision every %@ pixels.": "每 %@ 像素一个细分。",
    "How far apart the screen's lines are": "屏幕扫描线的间距",
    "Keeps this point fixed. Artwork is not scaled; cropped content remains outside the canvas.":
        "保持该点固定。内容不缩放；被裁掉的部分仍保留在画布之外。",
    "Show Grid": "显示网格",
    "Show Guides": "显示参考线",
    "Show Rulers": "显示标尺",
    "Grid Color": "网格颜色",
    "Horizontal ruler": "水平标尺",
    "Vertical ruler": "垂直标尺",
    "Lock Guides": "锁定参考线",

    # ---- camera raw: the long help strings ----
    "Applies generic profile strength when camera metadata is not available.":
        "在没有相机元数据时，应用通用的配置文件强度。",
    "No lens metadata on this layer. Profile sliders set generic correction strength.":
        "该图层没有镜头元数据。配置文件滑块设置的是通用校正强度。",
    "Auto balances the average color. Custom follows Temperature and Tint.":
        "自动按平均色进行平衡。自定则跟随色温与色调。",
    "Chooses how strongly the calibration sliders below are applied. Version 6 is the current default.":
        "决定下方校准滑块的生效强度。版本 6 是当前的默认值。",
    "Clear the haze that leaves background showing through thin areas":
        "清除让薄处透出背景的雾霾",
    "Color the result while keeping its tones, for a sepia or a cyanotype":
        "在保留明暗层次的同时为结果着色，用于棕褐或蓝晒效果",
    "Diffusion is soft and wide, Bloom is tighter, and Halation is a red fringe.":
        "漫射柔和而宽广，泛光更集中，光晕则是红色边缘。",
    "Dims the picture outside this color's range. It is not kept when you press OK.":
        "压暗该颜色范围之外的画面。按下“好”之后不会保留。",
    "Highlight Priority protects bright edges. Color Priority also reduces color. Paint Overlay covers the edges evenly.":
        "高光优先保护明亮边缘。颜色优先同时降低饱和度。绘画叠加则均匀覆盖边缘。",
    "Positive straightens lines that bow outward (barrel); negative, lines that bow inward (pincushion).":
        "正值校正向外鼓起的线条（桶形）；负值校正向内凹的线条（枕形）。",
    "Positive values tighten the detected mask inward; negative values expand it outward":
        "正值让检测到的蒙版向内收紧，负值向外扩张",
    "Pull the mask onto the image's own edges, which recovers hair and fur":
        "把蒙版吸附到图像自身的边缘上，可找回发丝与毛发",
    "Pulls red and blue fringes apart toward the center to reduce color edging.":
        "把红蓝色边向中心拉开，以减少彩色镶边。",
    "Basic is quick; Advanced refines the mask against the layer's own detail, for hair and fur":
        "基本模式更快；高级模式结合图层自身的细节细化蒙版，适合发丝与毛发",
    "Blend the chosen color into the edges while keeping the center unchanged":
        "把所选颜色混入边缘，同时保持中心不变",
    "Make each dithered pixel this many pixels across, for a chunky old-screen look":
        "把每个抖动像素放大到这么多像素，呈现老式屏幕的颗粒感",
    "Make the lines waver sideways down the screen, like a CRT losing sync":
        "让线条沿屏幕向下左右摆动，如同失去同步的 CRT",
    "More ink (darker) or less before dithering": "抖动前的着墨量：越多越暗",
    "Tones per channel: 2 is pure black and white": "每通道的色调数：2 即纯黑与纯白",
    "How much of each pixel's error spreads to its neighbors. Less gives flatter areas":
        "每个像素的误差向邻近像素扩散的比例。越小则区域越平",
    "The characters to draw with, in any order: each spot gets the one whose ink best matches its tone":
        "用于绘制的字符，顺序不限：每个位置取墨量最接近其色调的那个",
    "The height of each line of characters": "每行字符的高度",
    "Draw each chunky pixel as a solid square, or as a round dot like a dot-matrix screen":
        "把每个大像素画成实心方块，或像点阵屏那样的圆点",
    "Linear runs along the line; Radial spreads out from the start point":
        "线性沿直线方向延伸；径向从起点向外扩散",
    "Break the lines into glowing beads": "把线条断开成发光的珠子",
    "Light blooming around the lines, like a CRT's phosphors":
        "线条周围的光晕，如同 CRT 荧光粉的余辉",
    "Distribution": "分布",
    "Gaussian": "高斯",

    # ---- text ----
    "Font face, including bold and italic variants": "字体，包含粗体与斜体变体",
    "Line height, baseline to baseline. Empty or 0 is Auto: 120% of the font size.":
        "行高，从基线到基线。留空或填 0 表示自动：字号的 120%。",
    "Text fields keep standard macOS editing keys. Dialogs share the Apply/Cancel assignments above. Numeric fields use Up/Down, with Shift for larger steps. Standard macOS commands include ⌘Q to quit and ⌃⌘F for full screen. The shortcut editor itself always uses Return to save and Esc to cancel when not recording.":
        "文本输入框保留 macOS 标准的编辑按键。对话框共用上方的“应用/取消”分配。数值输入框使用上下方向键，按住 Shift 步进更大。macOS 标准命令包括 ⌘Q 退出与 ⌃⌘F 全屏。快捷键编辑器本身在未录制时，始终用回车保存、Esc 取消。",
    "Contextual keys & mouse gestures": "情境按键与鼠标手势",
    "Text Editing": "文本编辑",
    "Canvas & Layers": "画布与图层",
    "Menus": "菜单",
    "Click a shortcut, then press its new key combination. Changes apply when you save.":
        "单击一个快捷键，然后按下新的组合键。保存后生效。",
    "Press a shortcut": "请按下快捷键",
    "Press keys…": "请按键…",
    "Finish editing text": "完成文字编辑",
    "Editable text": "可编辑文字",
    "Editable text layer": "可编辑文字图层",
    "New Text Layer": "新建文字图层",
    "Text · Double-click to edit": "文字 · 双击可编辑",
    "Characters": "字符",
    "Decrease leading": "减小行距",
    "Increase leading": "增大行距",
    "Decrease tracking": "减小字距",
    "Increase tracking": "增大字距",

    # ---- shortcut descriptions and tool labels ----
    "Cycle tool mode": "循环切换工具模式",
    "Cycle shape kind": "循环切换形状类型",
    "Next blend mode": "下一个混合模式",
    "Previous blend mode": "上一个混合模式",
    "Lasso / cycle mode": "套索 / 循环模式",
    "Marquee / cycle shape": "选框 / 循环形状",
    "Temporary Hand tool (hold)": "临时抓手工具（按住）",
    "Move / Transform tool": "移动 / 变换工具",
    "Brush (B) · Eraser (E)": "画笔 (B) · 橡皮擦 (E)",
    "Brush tool": "画笔工具",
    "Crop tool": "裁剪工具",
    "Crop (C)": "裁剪 (C)",
    "Eyedropper (I)": "吸管 (I)",
    "Eyedropper tool": "吸管工具",
    "Gradient (G)": "渐变 (G)",
    "Gradient tool": "渐变工具",
    "Hand (H)": "抓手 (H)",
    "Hand tool": "抓手工具",
    "Lasso (L)": "套索 (L)",
    "Magic Wand": "魔棒",
    "Marquee (M)": "选框 (M)",
    "Move / Transform (V)": "移动 / 变换 (V)",
    "Polygonal Lasso": "多边形套索",
    "Rectangular Marquee": "矩形选框",
    "Elliptical Marquee": "椭圆选框",
    "Shape tool": "形状工具",
    "Spot Healing Brush (J)": "污点修复画笔 (J)",
    "Type (T)": "文字 (T)",
    "Type tool": "文字工具",
    "Zoom (Z)": "缩放 (Z)",
    "Zoom tool": "缩放工具",
    "Zoom in": "放大",
    "Zoom out": "缩小",
    "Select tool": "选择工具",
    "Press Tab to switch between Wand and Object": "按 Tab 在魔棒与对象之间切换",
    "Press L to switch between Freehand and Polygonal": "按 L 在手绘与多边形之间切换",
    "Press M to switch between Rectangle and Ellipse": "按 M 在矩形与椭圆之间切换",
    "Copy from the active layer only, or from every visible layer as shown":
        "仅从当前图层拷贝，或按画面所示从所有可见图层拷贝",
    "Read colors from the active layer only, or from every visible layer as shown":
        "仅从当前图层读取颜色，或按画面所示从所有可见图层读取",
    "Lock aspect ratio. Hold Shift while dragging a handle to turn it the other way.":
        "锁定长宽比。拖动控制点时按住 Shift 可反向。",
    "Scale width and height together, about the center": "以中心为基准，同时缩放宽与高",
    "Round the rectangle's corners by this many pixels; 0 keeps them square":
        "矩形圆角的像素数；0 表示保持直角",
    "How far the blur softens, in pixels": "模糊的柔化半径（像素）",
    "Make each dithered pixel this many pixels across, for a chunky old-screen look":
        "把每个抖动像素放大到这么多像素，呈现老式屏幕的颗粒感",
    "Off leaves the picture as it is. Guided straightens from lines you draw on the picture.":
        "关闭则保持画面不变。引导式依据你在画面上绘制的线条进行校正。",
    "Perspective allows stronger keystone. Rectilinear keeps the warp gentler.":
        "透视允许更强的梯形校正。直线方式的变形更温和。",
    "Shrink the mask to drop the rim of background color around the subject, or grow it":
        "收缩蒙版可去掉主体周围残留的背景色边，或向外扩张",
    "Smooth the detected object outline; turn off for the raw pixel mask":
        "平滑检测到的对象轮廓；关闭则使用原始像素蒙版",
    "Applying…": "正在应用…",
    "Loading histogram…": "正在载入直方图…",
}


    # ---- the tail, added after cross-checking against Xcode's extraction ----
ZH_PROSE2.update({
    "%@ the selection by this many pixels": "%@选区这么多像素",
    "Apply outside this range instead": "改为应用此范围之外",
    "Choose the %@ color": "选取%@颜色",
    "Choose the vignette color": "选取晕影颜色",
    "Color that fills transparent areas": "填充透明区域的颜色",
    "Constrain Crop": "约束裁剪",
    "Crops empty edges after the transform and fits the result back into the frame.":
        "变换后裁掉空白边缘，并把结果重新适配回画框。",
    "Enable Lens Profile Corrections": "启用镜头配置文件校正",
    "Fill the selection using surrounding pixels from this layer.":
        "用该图层周围的像素填充选区。",
    "Hold Shift to add or Option to subtract for one outline":
        "按住 Shift 加选、Option 减选，可合成一条轮廓",
    "Protect bright areas near the edge": "保护边缘附近的明亮区域",
    "Remove Chromatic Aberration": "移除色差",
})
