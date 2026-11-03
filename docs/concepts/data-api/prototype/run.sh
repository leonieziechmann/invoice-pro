#!/usr/bin/env bash
# Reproduces the core proofs of the data API prototype (see README.md next to
# this script) on throw-away clones of this repository:
#   1. the skeleton compiles alone, with its samples;
#   2. hydrated from a file, from inline JSON, from stdin and from TOML, it is
#      byte-identical to the same invoice written by hand with invoice-pro
#      0.6.0 (PDF/A-3b, factur-x.xml included);
#   3. data without an invoice number gives a draft without XML, and
#      `strict` stops the build;
#   4. the post code of the recipient picks the coat of arms, and the custom
#      field `wappen` overrides it.
#
# Usage: run.sh [work-dir]   (default: a new temporary directory)
# Needs git, Typst ($TYPST_BIN, default `typst`; 0.14 or 0.15), python3, and
# optionally pdfdetach (poppler) to count the embedded files.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
TYPST="${TYPST_BIN:-typst}"
BASE="df934a7" # main at invoice-pro 0.6.0, the base of the patches
W="${1:-$(mktemp -d)}"
mkdir -p "$W"
W="$(cd "$W" && pwd)"

echo "work dir: $W ($("$TYPST" --version))"
if [ ! -d "$W/pristine" ]; then
  git clone -q "$REPO" "$W/pristine"
  git -C "$W/pristine" checkout -q --detach "$BASE"
fi
if [ ! -d "$W/repo" ]; then
  git clone -q "$REPO" "$W/repo"
  git -C "$W/repo" checkout -q --detach "$BASE"
  git -C "$W/repo" -c user.name=prototype -c user.email=prototype@invalid \
    am -q "$HERE"/patches/*.patch
fi
rm -rf "$W/proto"
mkdir -p "$W/proto" "$W/out" "$W/dev"
cp -r "$HERE/examples" "$HERE/data" "$W/proto/"
# `--input invoice-pro-data-file=/dev/stdin` resolves inside --root.
ln -sfn /dev/stdin "$W/dev/stdin"

cd "$W/proto/examples"
C=(--root "$W" --creation-timestamp 1767225600 --pdf-standard a-3b)
O="$W/out"
fails=0
ok() { echo "PASS $*"; }
no() {
  echo "FAIL $*"
  fails=$((fails + 1))
}
md5() { md5sum <"$1" | cut -c1-12; }
attachments() {
  if command -v pdfdetach >/dev/null; then
    pdfdetach -list "$1" | head -1 | awk '{print $1}'
  else
    echo "?"
  fi
}
arms() {
  "$TYPST" query --root "$W" skeleton.typ image --field source "$@" 2>/dev/null |
    python3 -c 'import json,sys; print(",".join(x for x in json.load(sys.stdin) if x.startswith("wappen")))'
}

# 1. The skeleton alone.
if "$TYPST" compile "${C[@]}" skeleton.typ "$O/alone.pdf" 2>"$O/alone.err"; then
  ok "skeleton alone compiles (arms: $(arms), embedded files: $(attachments "$O/alone.pdf"))"
else
  no "skeleton alone: $(grep -m1 error "$O/alone.err")"
fi

# 2. Hydrated == hand-written on 0.6.0.
J=../data/2026-0042.json
"$TYPST" compile "${C[@]}" --input lib=pristine handwritten.typ "$O/hand.pdf"
"$TYPST" compile "${C[@]}" skeleton.typ "$O/file.pdf" --input invoice-pro-data-file="$J"
"$TYPST" compile "${C[@]}" skeleton.typ "$O/inline.pdf" --input invoice-pro-data="$(cat "$J")"
"$TYPST" compile "${C[@]}" skeleton.typ "$O/stdin.pdf" --input invoice-pro-data-file=/dev/stdin <"$J"
"$TYPST" compile "${C[@]}" skeleton.typ "$O/toml.pdf" --input invoice-pro-data-file=../data/2026-0042.toml
h=$(md5 "$O/hand.pdf")
for v in file inline stdin toml; do
  if [ "$(md5 "$O/$v.pdf")" = "$h" ]; then
    ok "hydrated ($v) == hand-written on 0.6.0: $h"
  else
    no "hydrated ($v) $(md5 "$O/$v.pdf") != hand-written $h"
  fi
done

# 3. No sample leaks: a missing invoice number is a draft without XML.
B=../data/broken-no-invoice-nr.json
"$TYPST" compile "${C[@]}" skeleton.typ "$O/draft.pdf" --input invoice-pro-data-file="$B" 2>/dev/null
n=$(attachments "$O/draft.pdf")
if [ "$n" = "0" ] || [ "$n" = "?" ]; then
  ok "missing invoice-nr: draft, embedded files: $n"
else
  no "missing invoice-nr: $n embedded files"
fi
if "$TYPST" compile "${C[@]}" skeleton.typ "$O/strict.pdf" --input invoice-pro-data-file="$B" \
  --input invoice-pro-validation=strict 2>"$O/strict.err"; then
  no "missing invoice-nr under strict: the build did not stop"
else
  ok "missing invoice-nr under strict: stops ($(grep -m1 -o 'invoice-nr[^.]*' "$O/strict.err" || true))"
fi

# 4. The coat of arms by post code; custom.wappen overrides.
declare -A WANT=([80331]=bayern [20095]=hamburg [10115]=berlin [50667]=neutral [override]=muenchen)
for k in 80331 20095 10115 50667 override; do
  a=$(arms --input invoice-pro-data-file="../data/w-$k.json")
  if [ "$a" = "wappen/${WANT[$k]}.svg" ]; then
    ok "arms for $k: $a"
  else
    no "arms for $k: $a (want ${WANT[$k]})"
  fi
done

echo "failures: $fails"
[ "$fails" = 0 ]
