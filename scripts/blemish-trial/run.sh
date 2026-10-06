#!/bin/bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
  echo 'Usage: run.sh PHOTO NEW_OUTPUT' >&2
  exit 2
fi
trial_repo=$(cd "$(dirname "$0")/../.." && pwd)
trial_workspace=$(mktemp -d /tmp/portrait-blemish.XXXXXX)
trap 'python3 -c '\''import shutil,sys; shutil.rmtree(sys.argv[1])'\'' "$trial_workspace"' EXIT
python3 - "$trial_workspace" "$trial_repo" <<'PY'
from pathlib import Path
import sys,json,shutil
workspace,repo=map(Path,sys.argv[1:])
(workspace/'Sources/Trial').mkdir(parents=True)
shutil.copy2(repo/'scripts/blemish-trial/main.swift',workspace/'Sources/Trial/main.swift')
(workspace/'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "BlemishTrial", platforms: [.macOS(.v15)],
 dependencies: [.package(path: '''+json.dumps(str(repo/'PortraitFoundation'))+''')],
 targets: [.executableTarget(name: "Trial", dependencies: [
 .product(name: "PortraitAnalysis", package: "PortraitFoundation"),
 .product(name: "PortraitCore", package: "PortraitFoundation"),
 .product(name: "PortraitMCP", package: "PortraitFoundation")])])
''')
PY
swift build -c release --package-path "$trial_workspace"
trial_binary=$(python3 - "$trial_workspace" <<'PY'
from pathlib import Path
import sys
paths=[p for p in (Path(sys.argv[1])/'.build').rglob('Trial') if p.is_file() and not any(q.endswith('.dSYM') for q in p.parts)]
assert len(paths)==1,paths
print(paths[0])
PY
)
"$trial_binary" "$1" "$2"
