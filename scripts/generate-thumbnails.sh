#!/usr/bin/env bash
# Generate archive/banner thumbnails from articles.json image_path entries.
# Run locally on a developer machine only — never on the production web server.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON="$ROOT/articles.json"
THUMB_DIR="$ROOT/images/thumbs"
MAX_WIDTH=800
QUALITY=80

if [[ ! -f "$JSON" ]]; then
  echo "Error: $JSON not found" >&2
  exit 1
fi

mkdir -p "$THUMB_DIR"

resize_with_ffmpeg() {
  local src="$1"
  local dest="$2"
  ffmpeg -y -loglevel error -i "$src" \
    -vf "scale='min($MAX_WIDTH,iw)':-2" \
    -q:v "$(( (100 - QUALITY) / 3 + 2 ))" \
    "$dest"
}

resize_with_magick() {
  local src="$1"
  local dest="$2"
  magick "$src" -resize "${MAX_WIDTH}x>" -quality "$QUALITY" "$dest"
}

resize_image() {
  local src="$1"
  local dest="$2"

  if command -v ffmpeg >/dev/null 2>&1; then
    resize_with_ffmpeg "$src" "$dest"
  elif command -v magick >/dev/null 2>&1; then
    resize_with_magick "$src" "$dest"
  elif command -v convert >/dev/null 2>&1; then
    convert "$src" -resize "${MAX_WIDTH}x>" -quality "$QUALITY" "$dest"
  else
    echo "Error: install ffmpeg or ImageMagick locally to generate thumbnails." >&2
    exit 1
  fi
}

echo "Reading image paths from articles.json..."
mapfile -t IMAGE_PATHS < <(python3 - "$JSON" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
seen = set()
for article in data:
    path = article.get("image_path", "")
    if path and path not in seen:
        seen.add(path)
        print(path)
PY
)

cd "$ROOT"
generated=0
skipped=0

for rel_path in "${IMAGE_PATHS[@]}"; do
  src="$ROOT/$rel_path"
  base="$(basename "$rel_path")"
  stem="${base%.*}"
  dest="$THUMB_DIR/${stem}.jpg"

  if [[ ! -f "$src" ]]; then
    echo "Skip (missing): $rel_path"
    ((skipped++)) || true
    continue
  fi

  echo "Thumbnail: $rel_path -> images/thumbs/${stem}.jpg"
  resize_image "$src" "$dest"
  ((generated++)) || true
done

echo ""
echo "Done: $generated generated, $skipped skipped."
echo "Deploy images/thumbs/ to the server together with other image assets."
