# Diagnostic: which enum values the interface shows have no translation yet.
# The authoritative check is CompositorTests/DisplayNameTests; this just prints the list
# faster than digging it out of an .xcresult.
import re, glob, json, os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

NAMES = """LayerBlendMode AdjustmentKind FilterKind LayerSampling ShapeKind TextAlignment
LayerEffectKind GradientShape GradientStyle LassoKind SelectionMode WandMode BrushToolMode
BlurToolMode SpotHealingMode CanvasUnit LevelsChannel ColorRange DitherStyle DitherColors
DitherPixelShape CameraRawWhiteBalance CameraRawCurvePage CameraRawGlowStyle
CameraRawVignetteStyle CameraRawUprightMode CameraRawProjection CameraRawProcessVersion
CameraRawMixerPage CameraRawMixerTab CameraRawGradePage CameraRawPointChannel""".split()
NESTED = ["Preset", "Style"]

files = {f: open(f, encoding="utf-8").read()
         for f in glob.glob(os.path.join(REPO, "Compositor/**/*.swift"), recursive=True)}
catalog = json.load(open(os.path.join(REPO, "Compositor/Localizable.xcstrings")))["strings"]

def body(text, idx):
    start = text.index("{", idx); depth, i = 0, start
    while i < len(text):
        if text[i] == "{": depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0: return text[start:i+1]
        i += 1
    return ""

def values(b):
    # Inside an enum body every `= "..."` is a case value, whether the enum spans one line
    # or twenty.
    return set(re.findall(r'=\s*"((?:[^"\\]|\\.)*)"', b))

found = {}
for name in NAMES + NESTED:
    for text in files.values():
        m = re.search(r'enum %s\s*:\s*String' % re.escape(name), text)
        if m:
            found.setdefault(name, set()).update(values(body(text, m.end())))

allv = set().union(*found.values()) if found else set()
missing = sorted(v for v in allv if v not in catalog)
print(f"检查枚举 {len(found)} 个，值 {len(allv)} 个")
print(f"缺失 {len(missing)}")
for v in missing:
    print("   ", repr(v))
