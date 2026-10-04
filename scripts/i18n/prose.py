# -*- coding: utf-8 -*-
"""zh-Hans for the prose: tooltips, help text, and the labels that carry a format argument.

Keys are exactly what Xcode extracts — `%@` for a String, `%lld` for an Int, `%%` for a
literal percent — so they were taken from `xcodebuild -exportLocalizations` rather than
hand-written. A hand-written `%arg` (what `xcstringstool extract` prints) never matches
what SwiftUI looks up at runtime.

Split across two files only because of length; `prose2.py` holds the rest.

Translations favour how a Chinese retoucher talks over how the English is shaped. Where a
Photoshop term exists it is used: 溢出 for clipping, 剪贴蒙版 for clipping mask, 直方图 for
histogram, 色阶 for levels.
"""

ZH_PROSE = {
    # ---- units, symbols, fragments ----
    "#": "#",
    "%": "%",
    "%lld": "%lld",
    "%lld%%": "%lld%%",
    "100%": "100%",
    "px": "px",
    "pixels": "像素",
    "pixels/inch": "像素/英寸",
    "%@ color": "%@ 颜色",
    "%@ × %@ px · sRGB": "%@ × %@ px · sRGB",
    "%@ %@. %@": "%@ %@。%@",
    "%@ uncompressed RGBA canvas": "%@ 未压缩 RGBA 画布",
    "%lld degrees": "%lld 度",
    "%lld × %lld px": "%lld × %lld px",
    "%lld°  %lld": "%lld°  %lld",
    "In %lld   Out %lld": "输入 %lld   输出 %lld",
    "Input %lld · Output %lld": "输入 %lld · 输出 %lld",
    "Current: %lld × %lld pixels": "当前：%lld × %lld 像素",
    "Result: %lld × %lld pixels": "结果：%lld × %lld 像素",
    "New: %lld × %lld pixels · %@ uncompressed": "新建：%lld × %lld 像素 · %@ 未压缩",
    "Compositor": "Compositor",
    "sRGB · Transparent": "sRGB · 透明",

    # ---- short labels shared across panels ----
    "Aligned": "对齐",
    "Anchor": "定位点",
    "Anti-alias": "消除锯齿",
    "Based On": "基于",
    "Blend": "混合",
    "Brush": "画笔",
    "Channel": "通道",
    "Characters": "字符",
    "Colorize": "着色",
    "Component": "分量",
    "Contiguous": "连续",
    "Curve": "曲线",
    "Dark": "暗色",
    "Defringe": "去边",
    "Distribution": "分布",
    "Draw Guides": "绘制参考线",
    "Edge": "边缘",
    "Eraser": "橡皮擦",
    "Export…": "导出…",
    "Extension color": "扩展区域颜色",
    "Fit": "适合窗口",
    "Flip H": "水平翻转",
    "Flip V": "垂直翻转",
    "Foreground color": "前景色",
    "Fuzziness": "容差",
    "Gaussian": "高斯",
    "Gradient": "渐变",
    "Grading": "颜色分级",
    "Green Primary": "绿原色",
    "Gridline every": "网格线间隔",
    "Hex": "十六进制",
    "Hex color": "十六进制颜色",
    "High": "高",
    "Inside": "内部",
    "Lasso": "套索",
    "Leading": "行距",
    "Light": "亮色",
    "Light on Dark": "暗底亮纹",
    "Low": "低",
    "Magic": "魔棒",
    "Marquee": "选框",
    "Mask": "蒙版",
    "Mask background": "蒙版背景",
    "Mask foreground": "蒙版前景",
    "Medium Contrast": "中等对比度",
    "Mixer": "混色器",
    "Monochromatic": "单色",
    "New color": "新颜色",
    "Noise Reduction": "降噪",
    "Opacity percent": "不透明度百分比",
    "Outside": "外部",
    "Pan": "抓手",
    "Parametric": "参数",
    "Pixel Shape": "像素形状",
    "Preserve Luminosity": "保留明度",
    "Preset": "预设",
    "Preset sizes": "预设尺寸",
    "Process": "处理版本",
    "Projection": "投影方式",
    "Quality": "品质",
    "Ratio": "比例",
    "Red Primary": "红原色",
    "Remove point": "删除控制点",
    "Resample": "重新取样",
    "Reset curve": "复位曲线",
    "Resize": "调整大小",
    "Reverse": "反向",
    "Sample Size": "取样大小",
    "Sampling": "取样",
    "Saturation and brightness": "饱和度与亮度",
    "Search shortcuts": "搜索快捷键",
    "Selected": "已选择",
    "Shape": "形状",
    "Show Controls": "显示控件",
    "Smear": "涂抹",
    "Spot Healing": "污点修复",
    "Strong Contrast": "强对比度",
    "Subdivisions": "细分",
    "Swap colors": "交换颜色",
    "Targeted Adjustment": "目标调整",
    "Targeted adjustment": "目标调整",
    "Text color": "文字颜色",
    "This Layer": "当前图层",
    "Tracking": "字距",
    "Transform": "变换",
    "Transform Mask": "变换蒙版",
    "Trim": "裁切",
    "Trim Away": "裁切掉",
    "Type": "文字",
    "Uniform": "均匀",
    "Unsaved changes": "未保存的更改",
    "Updating…": "正在更新…",
    "Upright": "校正",
    "Visualize Range": "显示范围",
    "White Balance": "白平衡",
    "White Balance Selector": "白平衡选择器",
    "Working…": "正在处理…",
    "Zoom": "缩放",
    "Applying…": "正在应用…",
    "Blue Primary": "蓝原色",
    "Canvas Size": "画布大小",
    "Canvas extension": "画布扩展",
    "Clone Stamp": "仿制图章",
    "Default colors": "默认颜色",
    "Default colors (D)": "默认颜色 (D)",
    "Delete layer mask": "删除图层蒙版",
    "Delete selected effect": "删除选中的效果",
    "Delete selected layer": "删除选中的图层",
    "Delete selected layers": "删除选中的多个图层",
    "Edit Text": "编辑文字",
    "Empty selection": "空选区",
    "Export JPEG": "导出 JPEG",
    "Image Size": "图像大小",
    "Import image": "导入图像",
    "Importing images…": "正在导入图像…",
    "Layer effects": "图层效果",
    "Layer effects: stroke and drop shadow": "图层效果：描边与投影",
    "Loading histogram…": "正在载入直方图…",
    "New adjustment layer": "新建调整图层",
    "New blank layer": "新建空白图层",
    "New blank layer (⇧⌘N)": "新建空白图层 (⇧⌘N)",
    "New canvas": "新建画布",
    "New canvas (⌘N)": "新建画布 (⌘N)",
    "New canvas (⌘N) · Drop images here for new tabs":
        "新建画布 (⌘N) · 拖入图像可新建标签页",
    "New folder": "新建文件夹",
    "No layers yet": "还没有图层",
    "Open in a new project tab": "在新标签页中打开",
    "Open project": "打开项目",
    "Project tabs": "项目标签页",
    "Reading the Photoshop file…": "正在读取 Photoshop 文件…",
    "Ready when you are": "准备好了",
    "Select this picked color.": "选择这个取样颜色。",
    "Show clipped highlights in red on the preview.": "在预览中用红色显示溢出的高光。",
    "Show clipped shadows in blue on the preview.": "在预览中用蓝色显示溢出的阴影。",
    "Transparent canvas · sRGB": "透明画布 · sRGB",
    "Black · Hide": "黑 · 隐藏",
    "White · Reveal": "白 · 显示",
    "Highlight Clipping Indicator": "高光溢出指示",
    "Shadow Clipping Indicator": "阴影溢出指示",
    "RGB histogram": "RGB 直方图",
    "Drag to resize the panel": "拖动可调整面板大小",
    "Limited to the selection": "仅限选区内",
    "Remove every guide line.": "清除所有参考线。",
    "Lock aspect ratio": "锁定长宽比",
    "Lock original aspect ratio": "锁定原始长宽比",
    "Swap foreground and background (X)": "交换前景色与背景色 (X)",
    "Position": "位置",
    "Undo %@": "撤销%@",
    "Redo %@": "重做%@",
    "Show %@": "显示%@",
    "Hide %@": "隐藏%@",
    "Close %@": "关闭%@",
    "Edit %@.": "编辑%@。",
    "Develop “%@”": "显影“%@”",
    "Show %@ in the preview": "在预览中显示%@",
    "Hide %@ in the preview": "在预览中隐藏%@",
    "Zoom in (⌘+)": "放大 (⌘+)",
    "Zoom out (⌘−)": "缩小 (⌘−)",
    "Zoom percentage": "缩放百分比",
    "Zoom percentage (0.1–3200%). Press Return to apply.":
        "缩放百分比（0.1–3200%）。按回车应用。",
    "Zoom in (⌘+), now %@. At 100%% each pixel of the JPEG is one pixel of the screen, as on the canvas":
        "放大 (⌘+)，当前 %@。100%% 时 JPEG 的每个像素对应屏幕的一个像素，与画布一致",
    "Zoom out (⌘−), now %@": "缩小 (⌘−)，当前 %@",
    "Fit canvas in window (⌘0)": "使画布适合窗口 (⌘0)",
    "Show the whole image (⌘0)": "显示整幅图像 (⌘0)",
    "Actual pixels (⌘1)": "实际像素 (⌘1)",
    "Press 1–9 for 10–90%, 0 for 100%": "按 1–9 选择 10–90%，按 0 选择 100%",
    "Drag or scroll to move around; double-click switches between Fit and 100%":
        "拖动或滚动可移动视图；双击在“适合窗口”与 100% 之间切换",
    "Group selected layers (⌘G)": "编组所选图层 (⌘G)",
    "Auto Select": "自动选择",

    # ---- tooltips: painting and retouching ----
    "Paint with the foreground color (B), or erase pixels away (E)":
        "用前景色绘画 (B)，或擦除像素 (E)",
    "The brush trails the pointer on a string this long, so a shaky hand still draws a smooth line":
        "笔刷像被一根这么长的线牵着跟随指针，手抖也能画出平滑的线",
    "Option-click to set the source": "按住 Option 单击可设置源点",
    "Keep the source moving with the brush between strokes; off starts every stroke at the source point":
        "笔触之间源点随画笔移动；关闭则每次落笔都从源点开始",
    "Liquify pushes pixels · Blur softens · Smudge drags color along":
        "液化推动像素 · 模糊柔化 · 涂抹拖带颜色",
    "Drag to paint": "拖动以绘画",
    "Drag to erase": "拖动以擦除",
    "Drag to smudge": "拖动以涂抹",
    "Drag to soften": "拖动以柔化",
    "Drag to push pixels": "拖动以推动像素",
    "Decrease brush size": "减小画笔大小",
    "Increase brush size": "增大画笔大小",
    "Decrease brush hardness": "降低画笔硬度",
    "Increase brush hardness": "提高画笔硬度",
    "Shapes fill with the foreground color; click to change it":
        "形状以前景色填充；单击可更改颜色",
    "Shift-U (or Tab) steps through Rectangle, Ellipse and Line":
        "Shift-U（或 Tab）在矩形、椭圆与直线之间切换",
    "Option temporarily selects the eyedropper in painting tools. Shift constrains shapes/movement or adds to a selection; Option subtracts from selections or draws from center. Command-drag moves selected pixels; Command-Option-drag copies them. Option-drag duplicates layers/folders/effects; Option-click at a layer boundary toggles clipping. Command-click a thumbnail loads its selection. Control bypasses snapping. Right-drag adjusts brush size. Modifier-and-mouse gestures are fixed.":
        "在绘画工具中，Option 可临时切换到吸管。Shift 约束形状与移动方向，或加选；Option 减选，或从中心绘制。Command 拖动可移动选中的像素，Command-Option 拖动则拷贝。Option 拖动可复制图层/文件夹/效果；在图层交界处 Option 单击可切换剪贴蒙版。Command 单击缩略图可载入其选区。Control 可临时关闭对齐。右键拖动可调整画笔大小。修饰键与鼠标的组合手势不可更改。",

    # ---- tooltips: selections ----
    "Analyze the active layer only, or every visible layer as shown":
        "仅分析当前图层，或按画面所示分析所有可见图层",
    "Select layers by clicking the canvas. Hold Command to turn it the other way while you click.":
        "在画布上单击可选择图层。按住 Command 单击则反向选择。",
    "How far a color may be from the picked ones and still be selected":
        "颜色与取样值相差多少以内仍被选中",
    "How far each color channel (0–255) can differ from the clicked color and still be selected":
        "各颜色通道（0–255）与单击处相差多少以内仍被选中",
    "Select everything except those colors, such as all but a green screen":
        "选中这些颜色以外的全部区域，例如抠掉绿幕之外的画面",
    "Select only similar pixels connected to the one you click; off selects them everywhere":
        "只选中与单击处相连的相似像素；关闭则选中画面中所有相似像素",
    "Shift-click adds a color, Option-click takes one away.":
        "Shift 单击添加颜色，Option 单击移除颜色。",
    "Click the image to pick the color to select.": "单击图像以拾取要选择的颜色。",
    "Click the picture to save a color. Up to eight colors.":
        "单击图像以保存颜色，最多八个。",
    "Fade the edge of the selection by this many pixels": "按此像素数羽化选区边缘",
    "Smooth selection edges; turn off for hard pixel edges":
        "平滑选区边缘；关闭则得到硬像素边缘",
    "Expand Selection": "扩展选区",
    "Contract Selection": "收缩选区",
    "Feather Selection": "羽化选区",
    "Inverse Selection": "反选",
    "Move Selection": "移动选区",
    "Hide Selection": "隐藏选区",
    "Reveal Selection": "显示选区",
    "Duplicate Pixels": "拷贝像素",
    "Move Pixels": "移动像素",
    "Move pixels": "移动像素",
    "Select image pixels": "选择图像像素",
    "Load Mask Selection": "载入蒙版选区",
    "Load Layer Selection": "载入图层选区",
    "Select Subject": "选择主体",
    "Object Selection": "对象选择",
    "Floating Selection": "浮动选区",
    "Drag inside the wheel. Angle sets hue, distance sets saturation.":
        "在色轮内拖动。角度决定色相，距离决定饱和度。",
    "Drag to set hue and saturation. Double-click to reset this wheel.":
        "拖动可设置色相与饱和度。双击可复位该色轮。",
    "Hue and saturation of this wheel.": "该色轮的色相与饱和度。",
    "Hue around the wheel, saturation outward from the center. Control-click to show the histogram.":
        "沿圆环是色相，从中心向外是饱和度。Control 单击可显示直方图。",
    "Tones from black on the left to white on the right: blacks, shadows, midtones, highlights, whites. Control-click to show the vectorscope.":
        "从左到右由黑到白：黑色、阴影、中间调、高光、白色。Control 单击可显示矢量示波器。",
    "Drag up or down to lift or lower those tones. Drag a divider along the bottom to change which tones each region covers.":
        "上下拖动可提升或压低这些色调。拖动底部的分隔点可改变各区域覆盖的色调范围。",
    "Linear histogram with automatic vertical scaling. Tall spikes may extend beyond the graph; all tones from 0 to 255 remain included.":
        "线性直方图，纵向自动缩放。过高的尖峰可能超出图形，但 0–255 的全部色调仍计入。",
    "Original pixels · alpha-weighted histogram": "原始像素 · 按 alpha 加权",
    "Original pixels · selection and alpha-weighted histogram":
        "原始像素 · 按选区与 alpha 加权",
    "Underlying pixels · alpha-weighted histogram": "下层像素 · 按 alpha 加权",
    "Click a pixel that should be neutral.": "单击一个应当是中性灰的像素。",
    "Click the canvas to sample": "在画布上单击以取样",
    "Sample color": "取样颜色",
    "Red, green, and blue of the pixel under the pointer.":
        "指针所指像素的红、绿、蓝值。",
    "Match the clicked pixel, or the average of the pixels around it":
        "匹配单击处的像素，或取其周围像素的平均值",
    "Point Sample": "单点取样",
    "Click the fringe on the layer. Click the eyedropper again to stop.":
        "在图层上单击色边。再次点击吸管可停止。",
    "Click a purple or green fringe to set its hue range.":
        "单击紫色或绿色色边以设置其色相范围。",
    "Click the original layer. Click the eyedropper again to stop.":
        "单击原始图层。再次点击吸管可停止。",
    "Start of the hue range, in degrees.": "色相范围的起点（度）。",
    "End of the hue range, in degrees.": "色相范围的终点（度）。",
    "Input and output of the selected curve point.": "所选曲线控制点的输入与输出。",
    "Click to add a point. Drag to adjust.": "单击添加控制点，拖动进行调整。",
    "Drag a point. Click to add one. Double-click a point to remove it.":
        "拖动控制点。单击可添加，双击可删除。",
    "Replaces this curve with a straight line or a contrast curve.":
        "用直线或对比度曲线替换当前曲线。",
    "Drag a color in the picture. Nearby color families move together.":
        "在图像中拖动某个颜色，相邻色系会一起移动。",
    "Hue shifts the color, Saturation its strength, and Luminance its brightness.":
        "色相改变颜色，饱和度改变浓度，明度改变亮度。",
    "HSL lists every color. Color edits one family. Point Color adjusts a color you pick.":
        "HSL 列出全部颜色。颜色只编辑一个色系。点颜色调整你拾取的颜色。",
    "Three-Way shows shadows, midtones, and highlights. The other choices show one wheel.":
        "三向显示阴影、中间调与高光。其余选项各显示一个色轮。",
    "Parametric lifts tonal regions. Point places anchors on the curve.":
        "参数曲线抬升色调区域。点曲线在曲线上放置锚点。",
    "RGB changes brightness. Red, green, and blue also shift the color.":
        "RGB 改变亮度。红、绿、蓝还会改变颜色。",
    "Targeted adjustment: drag on the image to change that color's saturation, or its hue with Command held":
        "目标调整：在图像上拖动可改变该颜色的饱和度，按住 Command 则改变色相",
    "Put each pixel's brightness back afterwards, so only the color moves":
        "之后把每个像素的亮度还原，因此只有颜色发生变化",
}
