# -*- coding: utf-8 -*-
"""zh-Hans for the shortcuts editor.

Its own file because these names are the *table's* spelling, which is not always the menu's:
the menu says "Export PNG…" while the shortcut is called "Export PNG", and an ellipsis is
not part of a command's name in the editor. They are therefore distinct keys, and the menu
translations in `translations.py` do not cover them.
"""

ZH_SHORTCUTS = {
    # ---- menu commands, named without the ellipsis the menu adds ----
    "New Canvas": "新建画布",
    "Open Project": "打开项目",
    "Save As": "存储为",
    "Export PNG": "导出 PNG",
    "Select All": "全选",
    "Fill with Foreground": "填充前景色",
    "Fill with Background": "填充背景色",
    "Invert Pixels / Mask": "反相像素 / 蒙版",
    "Transform Layer / Selection": "变换图层 / 选区",
    "Toggle Levels preview": "切换色阶预览",

    # ---- canvas commands ----
    "Apply current canvas operation": "应用当前画布操作",
    "Cancel current canvas operation": "取消当前画布操作",
    "Blur / Smudge / Liquify": "模糊 / 涂抹 / 液化",
    "Delete selection / layer / effect / lasso point": "删除选区 / 图层 / 效果 / 套索点",
    "Reset colors": "复位颜色",
    "Swap foreground/background": "交换前景色/背景色",
    "Up": "上",
    "Down": "下",

    # ---- format strings: the placeholders are Xcode's, not Swift's ----
    "%@ by 10": "%@ ×10",
    "Nudge %@ %lld px": "轻推%@ %lld 像素",
    "Move selected pixels %@ %lld px": "移动选中像素%@ %lld 像素",
    "Opacity digit %lld (type two for exact %%)": "不透明度数字 %lld（连按两位表示精确百分比）",
}
