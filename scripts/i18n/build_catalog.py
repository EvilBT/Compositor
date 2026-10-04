# -*- coding: utf-8 -*-
"""Writes Compositor/Localizable.xcstrings from translations.py.

The catalog is the artifact; this script is how it is regenerated so a 500-entry
hand-maintained JSON file never has to be edited by hand.
"""
import json, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from translations import ZH
from glossary import ZH_ENUMS

OUT = os.path.join(REPO, "Compositor", "Localizable.xcstrings")

catalog = {"sourceLanguage": "en", "version": "1.0", "strings": {}}
# Glossary entries win on conflict: they are the reviewed domain terms.
merged = dict(ZH); merged.update(ZH_ENUMS)
for en, zh in merged.items():
    catalog["strings"][en] = {
        "localizations": {
            "zh-Hans": {"stringUnit": {"state": "translated", "value": zh}}
        }
    }

# Keep the on-disk order stable so diffs stay readable and reviewable.
catalog["strings"] = dict(sorted(catalog["strings"].items()))

with open(OUT, "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"wrote {OUT}")
print(f"  keys: {len(catalog['strings'])}")
print(f"  bytes: {os.path.getsize(OUT):,}")
