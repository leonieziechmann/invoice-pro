#!/bin/sh
# Contact sheet of all ten presets on IDENTICAL data (tests/matrix.typ: same body,
# same teal brand colour and logo, n=4): once on each preset's own layout (auto) and
# once all on din-5008-a, so the looks can be compared side by side.
# Usage: sh scripts/contact-sheet.sh  ->  out/contact-sheet-{auto,din-5008-a}.png
set -u
PRESETS="classic plain corporate elegant prestige bold technical soft compact boxed"
mkdir -p out/cs
for lay in auto din-5008-a; do
  for p in $PRESETS; do
    rm -f out/cs/$p-$lay-*.png
    typst compile --root . --input look=$p --input layout=$lay tests/matrix.typ "out/cs/$p-$lay-{p}.png" --ppi 50 || exit 1
  done
  typst compile --root . --input layout=$lay --input presets="$PRESETS" tests/contact-sheet.typ "out/contact-sheet-$lay.png" --ppi 60 || exit 1
done
echo "out/contact-sheet-auto.png out/contact-sheet-din-5008-a.png"
