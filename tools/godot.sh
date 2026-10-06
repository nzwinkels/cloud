#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep Godot logs, settings and font caches writable in cloud tasks.
runtime_dir="${TMPDIR:-/tmp}/snowboard-lab-$(id -u)"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$runtime_dir/cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$runtime_dir/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$runtime_dir/config}"
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
if command -v godot >/dev/null 2>&1; then
  engine="godot"
elif command -v godot4 >/dev/null 2>&1; then
  engine="godot4"
else
  echo "Godot 4.6 is vereist. Installeer de standaardversie (GDScript)." >&2
  exit 1
fi
exec "$engine" --path "$project_dir" "$@"
