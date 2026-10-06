#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$project_dir/.godot/exports/windows}"
mkdir -p "$output_dir"
output_dir="$(cd -- "$output_dir" && pwd)"
"$project_dir/tools/godot.sh" --headless --editor --import
"$project_dir/tools/godot.sh" --headless --export-release "Windows Desktop" "$output_dir/SnowboardLab.exe"
test -s "$output_dir/SnowboardLab.exe"
echo "Windows-export gemaakt: $output_dir/SnowboardLab.exe"
