#!/bin/sh
# Runs the whole prototype suite. Usage: sh scripts/run-all.sh  (from the prototype root)
set -u
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
c() { name=$1; shift; if typst compile --root . "$@" >/tmp/ipf.log 2>&1; then ok "$name"; else bad "$name"; sed -n 1,6p /tmp/ipf.log; fi; }
mkdir -p out
# the preset x layout matrix lives in scripts/checks-presets.sh (every preset, every layout)
c coverage tests/coverage.typ out/coverage.pdf
c envelopes tests/envelopes.typ out/envelopes.pdf
for lay in din-5008-a din-5008-b sn-010130-right sn-010130-left a4-window-right a4-window-left us-letter-10; do
  c "proof $lay" --input layout=$lay tests/proof.typ "out/proof-$lay-{p}.png" --ppi 60
done
c semantics tests/semantics.typ out/semantics.pdf
for p in p1 p4 p6 p8 scope; do c "walk $p" --input p=$p tests/walk.typ "out/w-$p-{p}.png" --ppi 60; done
for m in print pdf einvoice; do c "p2 $m" --input output=$m tests/p2-stationery.typ "out/p2-$m-{p}.png" --ppi 60; done
c "p2 einvoice a-3b" --pdf-standard a-3b --input output=einvoice tests/p2-stationery.typ out/p2-einvoice.pdf
c third-party --package-path tests/pkgs tests/third-party.typ "out/third-{p}.png" --ppi 60
for f in tests/doc/*.typ; do case $f in *prelude*|*corporate*) continue;; esac; c "doc $(basename $f)" --package-path tests/pkgs "$f" "out/doc-$(basename $f .typ)-{p}.png" --ppi 60; done
# compile-fail suite: every case must panic with the expected message (tests/errors/expected.txt)
n=$(grep -c . tests/errors/expected.txt)
i=1
: > out/err-actual.txt
while [ $i -le $n ]; do
  # strict level via the documented sys.inputs override; scripts/panic-text.awk
  # joins a multi-line panic into one line (typst 0.14 and 0.15 print it differently)
  msg=$(typst compile --root . --input invoice-pro-validation=strict --input case=$i tests/errors/err.typ out/err.pdf 2>&1 | awk -f scripts/panic-text.awk)
  echo "$msg" >> out/err-actual.txt
  i=$((i+1))
done
if diff -q tests/errors/expected.txt out/err-actual.txt >/dev/null; then ok "errors ($n cases, byte-identical)"; else bad "errors"; diff tests/errors/expected.txt out/err-actual.txt | head -20; fi
# validation levels (tests/validation): draft renders with markers, badge and report; none renders clean;
# strict and misuse panic with the expected messages (tests/validation/expected.txt)
for lv in classic:de corporate:en boxed:fr classic:it classic:es; do
  c "draft ${lv}" --input look=${lv%%:*} --input lang=${lv##*:} tests/validation/draft.typ "out/v-draft-${lv%%:*}-${lv##*:}-{p}.png" --ppi 60
done
c "validation api" tests/validation/api.typ out/v-api.pdf
c "themed findings under draft" tests/validation/themed.typ out/v-themed.pdf
c "none (clean render, same data)" --input level=none tests/validation/draft.typ "out/v-none-{p}.png" --ppi 60
c "draft under a-3b" --pdf-standard a-3b tests/validation/draft.typ out/v-draft-a3b.pdf
c "draft under ua-1" --pdf-standard ua-1 --input look=corporate tests/validation/draft.typ out/v-draft-ua1.pdf
: > out/val-actual.txt
for i in 1 2 3 4 5 6 7 8 9 10; do
  extra=""; [ $i = 7 ] && extra="--input invoice-pro-validation=strict"; [ $i = 9 ] && extra="--input invoice-pro-validation=strcit"
  typst compile --root . $extra --input case=$i tests/validation/strict.typ out/err.pdf 2>&1 | awk -f scripts/panic-text.awk >> out/val-actual.txt; echo >> out/val-actual.txt
done
if diff -q tests/validation/expected.txt out/val-actual.txt >/dev/null; then ok "validation strict/misuse (10 cases, byte-identical)"; else bad "validation strict/misuse"; diff tests/validation/expected.txt out/val-actual.txt | head -20; fi
# classification: every follow-level case of the error suite renders under draft and none; misuse panics under all levels
# (case 17 is a follow-level check too, but its fixture tests/fake.pdf is not a real PDF, so it cannot render)
for i in 4 5 6 7 8 9 11 24 25 26 27 28 29 32 33 37; do
  for lv in draft none; do c "err case $i renders under $lv" --input invoice-pro-validation=$lv --input case=$i tests/errors/err.typ out/err-ok.pdf; done
done
m=0
for i in 1 2 3 10 12 13 14 15 16 18 19 20 21 22 23 30 31 34 35 36 38 39 40; do
  if typst compile --root . --input invoice-pro-validation=none --input case=$i tests/errors/err.typ out/err.pdf >/dev/null 2>&1; then bad "misuse case $i must panic under none"; m=1; fi
done
[ $m = 0 ] && ok "misuse cases panic under none (23 cases)"
. scripts/checks-core.sh
. scripts/checks-naming.sh
. scripts/checks-api-frame.sh
. scripts/checks-api-body.sh
. scripts/checks-api-tokens.sh
. scripts/checks-presets.sh
. scripts/checks-presets-business.sh
. scripts/checks-presets-grid.sh
. scripts/checks-presets-serif.sh
. scripts/checks-presets-display.sh
. scripts/checks-audit.sh
. scripts/checks-fix-layouts.sh
. scripts/checks-fix-polish.sh
sh scripts/mutation.sh >/dev/null && echo "ok   token mutation (every frozen token changes a render)" || { echo "FAIL token mutation"; fail=1; }
exit $fail
