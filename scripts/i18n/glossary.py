# -*- coding: utf-8 -*-
"""zh-Hans for enum values that are shown in the interface.

These are the strings where the raw value is BOTH the on-disk format value and what the
person reads. Only the display is translated; `rawValue` stays frozen (see
Compositor/Document/LocalizedDisplay.swift).

Terminology follows Adobe's official Simplified Chinese for Photoshop, because that is the
vocabulary a retoucher already has in their hands. Where Photoshop has no equivalent the
term is chosen for what it does, not for its English shape.

Being a *glossary* rather than a phrasebook, it is also the reference for the prose
translations: "blend mode" is 混合模式 everywhere, not sometimes 混合方式.
"""

ZH_ENUMS = {
    # ---- blend modes (Photoshop 混合模式) ----
    "Normal": "正常",
    "Darken": "变暗",
    "Multiply": "正片叠底",
    "Color Burn": "颜色加深",
    "Linear Burn": "线性加深",
    "Lighten": "变亮",
    "Screen": "滤色",
    "Color Dodge": "颜色减淡",
    "Linear Dodge (Add)": "线性减淡（添加）",
    "Overlay": "叠加",
    "Soft Light": "柔光",
    "Hard Light": "强光",
    "Vivid Light": "亮光",
    "Linear Light": "线性光",
    "Pin Light": "点光",
    "Hard Mix": "实色混合",
    "Difference": "差值",
    "Exclusion": "排除",
    "Subtract": "减去",
    "Divide": "划分",
    "Hue": "色相",
    "Saturation": "饱和度",
    "Color": "颜色",
    "Luminosity": "明度",

    # ---- adjustments (调整) ----
    "Hue/Saturation": "色相/饱和度",
    "Levels": "色阶",
    "Curves": "曲线",
    "Exposure": "曝光度",
    "Gradient Map": "渐变映射",
    "Grain": "颗粒",
    "Add Noise": "添加杂色",
    "Gaussian Blur": "高斯模糊",
    "Motion Blur": "动感模糊",
    "Invert": "反相",
    "Black & White": "黑白",
    "Color Balance": "色彩平衡",

    # ---- filters (滤镜) ----
    "Vignette": "晕影",
    "Bloom / Glow": "辉光",
    "Dither": "抖动",
    "Tonal Contrast": "色调对比",
    "Lens Correction": "镜头校正",
    "Camera Raw Filter": "Camera Raw 滤镜",
    "Remove Background": "移除背景",
    "Content-Aware Fill": "内容识别填充",

    # ---- dither styles ----
    "ASCII": "ASCII",
    "Atkinson (Classic Mac)": "Atkinson（经典 Mac）",
    "Floyd–Steinberg": "Floyd–Steinberg",
    "Bayer 2 × 2": "拜耳 2 × 2",
    "Bayer 4 × 4": "拜耳 4 × 4",
    "Bayer 8 × 8": "拜耳 8 × 8",
    "Halftone Dots": "半调网点",
    "Halftone Lines": "半调线条",
    "Halftone Diamonds": "半调菱形",
    "Mac Patterns": "Mac 图案",
    "Scanlines (CRT)": "扫描线（CRT）",
    "Dot": "圆点",
    "Square": "方块",
    "Two Colors": "双色",
    "Original": "原色",

    # ---- sampling / geometry ----
    "Nearest": "邻近（硬边）",
    "Smooth": "平滑",
    "High quality": "高品质",
    "Rectangle": "矩形",
    "Ellipse": "椭圆",
    "Line": "直线",
    "Linear": "线性",
    "Radial": "径向",
    "Foreground to Background": "前景色到背景色",
    "Foreground to Transparent": "前景色到透明",
    "Polygonal": "多边形",
    "Freehand": "手绘",
    "Pixels": "像素",

    # ---- selection modes ----
    "New": "新建",
    "Add": "添加",
    "Expand": "扩展",

    # ---- tools and modes ----
    "Paint": "绘画",
    "Erase": "擦除",
    "Blur": "模糊",
    "Smudge": "涂抹",
    "Liquify": "液化",
    "Wand": "魔棒",
    "Object": "对象",
    "Content-Aware": "内容识别",
    "Create Texture": "创建纹理",
    "Proximity Match": "近似匹配",
    "Sample": "取样",

    # ---- layer effects ----
    "Stroke": "描边",

    # ---- camera raw ----
    "Auto": "自动",
    "Custom": "自定",
    "Basic": "基本",
    "Advanced": "高级",
    "Guided": "引导式",
    "Off": "关闭",
    "Perspective": "透视",
    "Rectilinear": "直线",
    "Diffusion": "漫射",
    "Bloom": "泛光",
    "Halation": "光晕",
    "Highlight Priority": "高光优先",
    "Color Priority": "颜色优先",
    "Paint Overlay": "绘画叠加",
    "RGB": "RGB",
    "HSL": "HSL",
    "Parametric": "参数",
    "Three-Way": "三向",
    "Version 1": "版本 1",
    "Version 2": "版本 2",
    "Version 3": "版本 3",
    "Version 4": "版本 4",
    "Version 5": "版本 5",
    "Version 6": "版本 6",
    "Histogram": "直方图",
    "Vectorscope": "矢量示波器",

    # ---- levels / curve sample points ----
    "Black": "黑场",
    "Contrast": "对比度",
    "Master": "全图",
    "Cyans": "青色",

    # ---- grid appearance ----
    "Light Gray": "浅灰", "Light Blue": "浅蓝", "Light Red": "浅红", "Green": "绿色",
    "Medium Blue": "中蓝", "Yellow": "黄色", "Magenta": "洋红", "Cyan": "青色", "Black": "黑色",
    "Lines": "实线", "Dashed Lines": "虚线", "Dots": "点",

    # ---- camera raw: the rest ----
    "Red": "红", "Green": "绿", "Blue": "蓝",
    "Point Color": "点颜色", "Luminance": "明度",
    "Midtones": "中间调", "Global": "全局",
    "Gray": "灰色", "Greens": "绿色", "Blues": "蓝色", "Purples": "紫色",
    "Yellows": "黄色", "Oranges": "橙色", "Reds": "红色", "Magentas": "洋红",
    "Aquas": "青色", "Purple": "紫色", "Orange": "橙色", "Aqua": "青色",

    # ---- layer effects (Photoshop 图层样式) ----
    "Drop Shadow": "投影",
    "Inner Shadow": "内阴影",
    "Outer Glow": "外发光",
    "Inner Glow": "内发光",
    "Color Overlay": "颜色叠加",

    # ---- point curve (Lightroom: 参数 / 点) ----
    "Point": "点",
}
