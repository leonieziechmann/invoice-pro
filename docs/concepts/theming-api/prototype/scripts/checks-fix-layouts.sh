#!/bin/sh
# Layout fixes: the dense header row, the Swiss layouts without a QR-bill zone, one
# page for small invoices. Sourced by scripts/run-all.sh (uses its c/ok/bad helpers).
PRESETS="classic plain corporate elegant prestige bold technical soft compact boxed"
mkdir -p out/fl
# a4-dense / us-letter-dense: recipient, references and title never overlap or squeeze (O8)
for look in $PRESETS; do
  for lay in a4-dense us-letter-dense; do
    c "dense header: $look/$lay" --input look=$look --input layout=$lay tests/dense-header.typ out/fl/dh.pdf
  done
done
# Swiss layouts: no QR-bill zone, no placeholder slip, 4 items on one page (O1);
# the zone is the explicit opt-in theme.layout.reserve-qr-bill(layout)
for look in $PRESETS; do
  for v in right left; do
    c "swiss: $look/sn-010130-$v, no QR-bill zone, 1 page" --input look=$look --input variant=$v tests/swiss.typ out/fl/sw.pdf
  done
done
c "swiss: layout auto for a Swiss sender, no QR-bill zone" --input variant=auto tests/swiss.typ out/fl/sw.pdf
c "swiss: reserve-qr-bill opt-in draws the zone" --input variant=reserved tests/swiss.typ out/fl/sw.pdf
# a 4-item invoice renders on exactly ONE page for every preset x every sender region (layout: auto)
for look in $PRESETS; do
  for reg in de at ch fr it es gb us; do
    c "one page: $look/$reg (auto, n=4)" --input look=$look --input region=$reg tests/one-page.typ out/fl/op.pdf
  done
done
