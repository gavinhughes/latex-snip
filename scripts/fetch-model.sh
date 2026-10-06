#!/bin/bash
# Download the built-in Texo formula-recognition model (AGPL-3.0, alephpi/FormulaNet
# on Hugging Face) into Models/Texo, pinned to a revision and checked by SHA-256.
# Safe to re-run: files that already match are skipped, partial downloads resume.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Models/Texo"
REPO="alephpi/FormulaNet"
REV="b2668efe5112082846fde4d446b9bfaab3989533"

# remote path | local name | sha256
FILES=(
  "onnx/encoder_model.onnx|encoder_model.onnx|fbd69cf63cf833db1e2ef40013d859b560671c1253278441a01bde4516b624ae"
  "onnx/decoder_model.onnx|decoder_model.onnx|00f07add62d74c78750cfda60ce8f1cff3d1774f913ca3f412e2e72f4189d7d4"
  "onnx/tokenizer.json|tokenizer.json|1240f9d178e1ad2a0076fe95ba62e332871c702accdd5ce3ae3ef33ffd6c3a1e"
)

mkdir -p "$DEST"
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

for entry in "${FILES[@]}"; do
  IFS='|' read -r remote name want <<<"$entry"
  out="$DEST/$name"
  if [[ -f "$out" && "$(sha "$out")" == "$want" ]]; then
    echo "ok       $name"
    continue
  fi
  echo "fetching $name"
  url="https://huggingface.co/$REPO/resolve/$REV/$remote"
  # Hugging Face sometimes drops long transfers; resume until complete.
  for attempt in $(seq 1 20); do
    if curl -fsSL --http1.1 -C - --retry 5 --retry-all-errors -o "$out" "$url"; then
      break
    fi
    echo "  retrying ($attempt)…" >&2
    sleep 2
  done
  got="$(sha "$out")"
  if [[ "$got" != "$want" ]]; then
    echo "error: $name sha256 $got, expected $want" >&2
    rm -f "$out"
    exit 1
  fi
  echo "ok       $name"
done
