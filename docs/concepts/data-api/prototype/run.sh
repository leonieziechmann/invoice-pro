#!/usr/bin/env bash
# Reproduces the core proofs of the data API prototype (see README.md next to
# this script) on throw-away clones of this repository:
#   1. the skeleton compiles alone, with its samples;
#   2. hydrated from a file, from inline JSON, from stdin and from TOML, it is
#      byte-identical to the same invoice written by hand with invoice-pro
#      0.6.0 (PDF/A-3b, factur-x.xml included);
#   3. data without an invoice number stops the build and lists the problem
#      (a hydrated invoice is strict by default), and the debug flag
#      `--input invoice-pro-validation=draft` gives a draft without XML;
#   4. the post code of the recipient picks the coat of arms, and the custom
#      field `wappen` overrides it;
#   5. the shipped template of the patched tree compiles alone to the same
#      PDF as the template of 0.6.0, and hydrates from a data file to a final
#      e-invoice.
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

# 3. Fail safe: a missing invoice number stops the build and lists the
#    problem; the debug flag renders a draft without XML (no sample leaks).
B=../data/broken-no-invoice-nr.json
if "$TYPST" compile "${C[@]}" skeleton.typ "$O/stop.pdf" --input invoice-pro-data-file="$B" \
  2>"$O/stop.err"; then
  no "missing invoice-nr: the build did not stop"
elif grep -q "invoice-nr is missing" "$O/stop.err" && grep -q "invoice-pro-validation=draft" "$O/stop.err"; then
  ok "missing invoice-nr: stops ($(grep -m1 -o 'invoice-nr is missing[^;]*' "$O/stop.err"); the hint names the draft flag)"
else
  no "missing invoice-nr: stops without the problem or the hint: $(grep -m1 error "$O/stop.err")"
fi
"$TYPST" compile "${C[@]}" skeleton.typ "$O/draft.pdf" --input invoice-pro-data-file="$B" \
  --input invoice-pro-validation=draft 2>/dev/null
n=$(attachments "$O/draft.pdf")
if [ "$n" = "0" ] || [ "$n" = "?" ]; then
  ok "missing invoice-nr with --input invoice-pro-validation=draft: draft, embedded files: $n"
else
  no "missing invoice-nr with the draft flag: $n embedded files"
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

# 5. The template (template/invoice.typ of the patched tree) is a skeleton:
#    alone it gives the PDF of the 0.6.0 template, with and without PDF/A;
#    hydrated from a file (the example data with the creditor ID that the
#    template lacks) it is a final e-invoice.
for t in pristine repo; do
  sed "s#@preview/invoice-pro:0.6.0#/$t/src/lib.typ#" "$W/$t/template/invoice.typ" >"template-$t.typ"
done
for std in none a-3b; do
  T0=(--root "$W" --creation-timestamp 1767225600)
  [ "$std" = none ] || T0+=(--pdf-standard "$std")
  a=$("$TYPST" compile "${T0[@]}" template-pristine.typ - 2>/dev/null | md5sum | cut -c1-12)
  b=$("$TYPST" compile "${T0[@]}" template-repo.typ - 2>/dev/null | md5sum | cut -c1-12)
  if [ "$a" = "$b" ]; then
    ok "template alone (PDF standard $std) == the 0.6.0 template: $b"
  else
    no "template alone (PDF standard $std): $b != 0.6.0 $a"
  fi
done
python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); d["payment"]["creditor-id"] = "DE98ZZZ09999999999"; json.dump(d, open(sys.argv[2], "w"), ensure_ascii=False)' \
  "$J" ../data/template-0042.json
if "$TYPST" compile "${C[@]}" template-repo.typ "$O/template.pdf" \
  --input invoice-pro-data-file=../data/template-0042.json 2>"$O/template.err"; then
  n=$(attachments "$O/template.pdf")
  if [ "$n" = "1" ] || [ "$n" = "?" ]; then
    ok "template hydrated from a file: final, embedded files: $n"
  else
    no "template hydrated: $n embedded files"
  fi
else
  no "template hydrated: $(grep -m1 error "$O/template.err")"
fi

echo "failures: $fails"
[ "$fails" = 0 ]
