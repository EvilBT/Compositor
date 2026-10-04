# -*- coding: utf-8 -*-
"""Merges the English→Chinese pairs into Compositor/Localizable.xcstrings.

The catalog is authoritative for *which* strings exist: Xcode extracts them from source
(`xcodebuild -exportLocalizations`), and that is the only way to get the real keys.
`xcstringstool extract` prints `%arg` for an interpolation where the catalog needs `%@` or
`%lld`, so a hand-written key silently never matches. This script therefore never invents
keys — it only fills in values for keys already there, and reports anything it is asked to
translate that the catalog has never heard of.

Sources, later ones winning:
  translations.py   interface copy, the first batch
  prose.py          tooltips and help text, part one
  prose2.py         tooltips and help text, part two
  glossary.py       enum values shown in the interface. Xcode cannot extract these: they
                    are looked up through a variable key in LocalizedDisplay.swift.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

from translations import ZH
from prose import ZH_PROSE
from prose2 import ZH_PROSE2
from glossary import ZH_ENUMS

CATALOG = os.path.join(REPO, "Compositor", "Localizable.xcstrings")
SOURCES = os.path.join(REPO, "Compositor")

merged = {}
for source in (ZH, ZH_PROSE, ZH_PROSE2, ZH_ENUMS):
    merged.update(source)

with open(CATALOG, encoding="utf-8") as f:
    catalog = json.load(f)

strings = catalog["strings"]
known = set(strings)

applied = 0
for key in known:
    if key not in merged:
        continue
    strings[key].setdefault("localizations", {})["zh-Hans"] = {
        "stringUnit": {"state": "translated", "value": merged[key]}
    }
    applied += 1

catalog["strings"] = dict(sorted(strings.items()))
with open(CATALOG, "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)
    f.write("\n")

# Keys we translate that the catalog does not have.
#
# These are NOT added. Xcode's localization build prunes any catalog entry it did not
# extract from source, so an entry added here would be deleted by the next build — and
# worse, the build recreates the key without its translation, silently losing it.
#
# The fix for an entry listed below is always the same: make the source literal extractable
# (`String(localized: "…")` or `NSLocalizedString("…", comment:)`), never a variable key.
# Then `xcodebuild -exportLocalizations` picks it up and this script fills it in.
unknown = sorted(k for k in merged if k not in known)

missing = sorted(k for k in strings if k not in merged and k)

print(f"catalog keys       {len(strings)}")
print(f"translations given {len(merged)}")
print(f"applied            {applied}")
print(f"still untranslated {len(missing)}")
if missing:
    for k in missing[:60]:
        print("   todo:", repr(k))
    if len(missing) > 60:
        print(f"   … and {len(missing) - 60} more")

if unknown:
    print()
    print(f"⚠️  {len(unknown)} translation(s) have no matching key in the catalog.")
    print("    Glossary terms are expected here (their key is a variable). Any *prose*")
    print("    key listed below is stale — the English changed in source, so the")
    print("    translation is orphaned and should be moved or deleted.")
    for k in unknown[:40]:
        print("   ?", repr(k))
    if len(unknown) > 40:
        print(f"   … and {len(unknown) - 40} more")
