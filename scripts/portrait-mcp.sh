#!/bin/sh
# Keep build logs on stderr so stdout contains only MCP messages.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
package_path="$project_root/PortraitFoundation"
swift build --package-path "$package_path" -c release --product portrait-mcp >&2
binary_path=$(swift build --package-path "$package_path" -c release --show-bin-path)
exec "$binary_path/portrait-mcp" "$@"
