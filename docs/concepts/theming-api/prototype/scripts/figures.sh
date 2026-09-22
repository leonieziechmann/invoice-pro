#!/bin/sh
# Regenerates the concept figures: sh scripts/figures.sh [output-dir]  (default out/figures)
set -e
dest=${1:-out/figures}
mkdir -p out/fig "$dest"
for look in classic corporate minimal plain; do
  for lay in din-5008-a din-5008-b us-letter-10 a4-digital sn-010130-right plain; do
    typst compile --root . --input look=$look --input layout=$lay tests/matrix.typ "out/fig/m-$look-$lay-{p}.png" --ppi 45
  done
done
for m in print pdf einvoice; do typst compile --root . --input output=$m --input n=26 tests/doc/p2.typ "out/fig/p2-$m-{p}.png" --ppi 55; done
typst compile --root . --input n=30 --input window=left tests/doc/p3.typ "out/fig/p3-{p}.png" --ppi 55
typst compile --root . --package-path tests/pkgs tests/doc/p9.typ "out/fig/p9-{p}.png" --ppi 70
typst compile --root . tests/doc/receipt.typ "out/fig/rc-{p}.png" --ppi 70
typst compile --root . tests/doc/p10.typ "out/fig/p10-{p}.png" --ppi 60
typst compile --root . tests/doc/p6.typ "out/fig/p6-{p}.png" --ppi 60
for f in matrix stationery swiss any-format parts; do
  typst compile --root . --input fig=$f tests/figures.typ "$dest/fig-$f.png" --ppi 110
done
