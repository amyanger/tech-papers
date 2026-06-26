#!/usr/bin/env bash
#
# Render a single paper to PDF and/or HTML using Pandoc.
#
# Usage:
#   scripts/build.sh <slug> [pdf|html|all]
#
# Examples:
#   scripts/build.sh 2026-06-26-prompt-injection-vibe-coding
#   scripts/build.sh 2026-06-26-prompt-injection-vibe-coding pdf
#
set -euo pipefail

SLUG="${1:?Usage: build.sh <slug> [pdf|html|all]}"
FORMAT="${2:-all}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAPER_DIR="$ROOT/papers/$SLUG"
SRC="$PAPER_DIR/paper.md"
BIB="$PAPER_DIR/refs.bib"
OUT="$ROOT/build"
CSS="$ROOT/styles/paper.css"

[ -f "$SRC" ] || { echo "error: no paper at $SRC" >&2; exit 1; }
mkdir -p "$OUT"

# Shared Pandoc options. --citeproc processes [@key] citations;
# --resource-path lets figures/ paths resolve relative to the paper.
COMMON=( "$SRC" --from markdown --citeproc --resource-path "$PAPER_DIR" )
[ -s "$BIB" ] && COMMON+=( --bibliography "$BIB" )

build_pdf() {
  echo "-> build/$SLUG.pdf"
  pandoc "${COMMON[@]}" --pdf-engine=tectonic -o "$OUT/$SLUG.pdf"
}

build_html() {
  echo "-> build/$SLUG.html"
  pandoc "${COMMON[@]}" --standalone --embed-resources --toc --css "$CSS" \
    -o "$OUT/$SLUG.html"
}

case "$FORMAT" in
  pdf)  build_pdf ;;
  html) build_html ;;
  all)  build_pdf; build_html ;;
  *)    echo "error: unknown format '$FORMAT' (use pdf|html|all)" >&2; exit 1 ;;
esac

echo "done."
