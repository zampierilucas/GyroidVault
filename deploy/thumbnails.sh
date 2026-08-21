#!/usr/bin/env bash
set -uo pipefail

LIB=${LIB:-/mnt/storage/3dprints}
JOBS=${JOBS:-8}

command -v f3d >/dev/null || { echo "f3d not installed: apt-get install -y f3d xvfb libgl1-mesa-dri"; exit 1; }
command -v xvfb-run >/dev/null || { echo "xvfb-run not installed: apt-get install -y xvfb"; exit 1; }

work=$(mktemp); fails=$(mktemp)

find "$LIB" -type d -print0 | while IFS= read -r -d '' d; do
  [ -e "$d/preview.png" ] && continue
  f=$(find "$d" -maxdepth 1 -type f \( -iname '*.stl' -o -iname '*.obj' -o -iname '*.step' -o -iname '*.stp' \) \
      ! -name '._*' -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -1 | cut -f2-)
  [ -n "$f" ] && printf '%s\n' "$f" >> "$work"
done

echo "rendering $(grep -c . "$work" 2>/dev/null || echo 0) models with f3d"

render() {
  local src=$1 out; out=$(dirname "$src")/preview.png
  timeout 300 xvfb-run -a f3d "$src" --output="$out" --resolution=600,600 --up=+Z \
    --camera-azimuth-angle=35 --camera-elevation-angle=25 -q --bg-color=0.12,0.12,0.14 >/dev/null 2>&1
  [ -s "$out" ] || { rm -f "$out"; echo "FAIL $src" >> "$FAILS"; }
}
export -f render
FAILS=$fails; export FAILS
xargs -a "$work" -d '\n' -P "$JOBS" -I{} bash -c 'render "$@"' _ {}

find "$LIB" -iname '*.f3d' ! -name '._*' -print0 | while IFS= read -r -d '' f; do
  d=$(dirname "$f")
  [ -e "$d/preview.png" ] && continue
  entry=$(unzip -Z1 "$f" 2>/dev/null | grep -iE 'previews/.+\.png$' | head -1)
  [ -z "$entry" ] && { echo "no embedded preview: $(basename "$f")"; continue; }
  esc=$(printf '%s' "$entry" | sed 's/\[/[[]/g')
  unzip -p "$f" "$esc" > "$d/preview.png" 2>/dev/null
  [ -s "$d/preview.png" ] || rm -f "$d/preview.png"
done

echo "previews now: $(find "$LIB" -name preview.png | wc -l)"
echo "render failures: $(grep -c '^FAIL' "$fails" 2>/dev/null || echo 0)"
grep '^FAIL' "$fails" 2>/dev/null | head -10
rm -f "$work" "$fails"

echo
echo "3MF files are skipped on purpose: f3d 1.3.1 cannot read them and GyroidVault"
echo "extracts their embedded thumbnail itself. Run a library scan to pick these up."
