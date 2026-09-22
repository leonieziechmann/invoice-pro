#!/bin/sh
# The shipped preset set as a whole (merge of the preset stages). Sourced by
# scripts/run-all.sh (uses its c/ok/bad helpers and $fail). Per-preset details
# (galleries, page budgets, own pairs) stay in scripts/checks-presets-<stage>.sh.
PRESETS="classic plain corporate elegant prestige bold technical soft compact boxed"
ALL_LAYOUTS="din-5008-a din-5008-b us-letter-10 a4-digital us-letter-digital sn-010130-right sn-010130-left a4-window-right a4-window-left plain a4-sidebar us-letter-sidebar a4-band us-letter-band a4-dense us-letter-dense"
mkdir -p out/ps
c "preset set: exactly the ten presets, all distinct" tests/presets-set.typ out/ps/set.pdf
# every preset (and the minimal recipe) on every layout, plus its own choice (auto)
for look in $PRESETS minimal; do
  for lay in auto $ALL_LAYOUTS; do
    [ $look = minimal ] && [ $lay = auto ] && continue
    c "matrix $look/$lay" --input look=$look --input layout=$lay tests/matrix.typ "out/ps/m-$look-$lay-{p}.png" --ppi 30
  done
done
# layout: auto follows the sender's region for every preset
r=0
for look in $PRESETS; do
  for reg in de at ch fr it es gb us nl; do
    typst compile --root . --input look=$look --input region=$reg tests/layout-region.typ out/ps/lr.pdf >/tmp/ipf.log 2>&1 || { bad "layout auto $look/$reg"; sed -n 1,3p /tmp/ipf.log; r=1; }
  done
done
[ $r = 0 ] && ok "layout auto by sender region (10 presets x 9 regions)"
for look in $PRESETS; do
  # WCAG AA (core pairs + the preset's checks.pairs) under strict, three brand seeds
  for col in none "#9fd8f5" "#c2185b"; do
    c "contrast 4.5 $look/$col" --input invoice-pro-validation=strict --input look=$look --input color=$col tests/preset-checks.typ out/ps/pc.pdf
  done
  # PDF/A-3b with ZUGFeRD (the XML is attached), PDF/UA-1 with an image logo with alt text
  if typst compile --root . --pdf-standard a-3b --input look=$look --input zugferd=1 tests/preset-checks.typ out/ps/a3b.pdf >/tmp/ipf.log 2>&1 && grep -a -q 'factur-x.xml' out/ps/a3b.pdf; then
    ok "a-3b + zugferd ($look)"
  else bad "a-3b + zugferd ($look)"; sed -n 1,6p /tmp/ipf.log; fi
  c "ua-1 image logo with alt ($look)" --pdf-standard ua-1 --input look=$look --input logo=image tests/preset-checks.typ out/ps/ua.pdf
  # a 4-item invoice fits on ONE page on the preset's default layout (German sender)
  rm -f out/ps/fit-*.png
  if typst compile --root . --input look=$look --input n=4 tests/preset-checks.typ "out/ps/fit-{p}.png" --ppi 20 >/tmp/ipf.log 2>&1 && [ ! -f out/ps/fit-2.png ]; then
    ok "n=4 fits on 1 page ($look, default layout)"
  else bad "n=4 fits on 1 page ($look, default layout)"; fi
done
# widow rule on every preset's default layout: the last item and the totals share a
# page around the first page boundary (soft: its totals card is separate by design)
w=0
for look in classic plain corporate elegant prestige bold technical compact boxed; do
  for n in 14 15 16 17 18 19 20 21 22; do
    for g in 0 1; do
      typst compile --root . --input look=$look --input layout=auto --input n=$n --input group=$g tests/widow.typ out/ps/w.pdf >/tmp/ipf.log 2>&1 || { bad "widow $look/auto n=$n group=$g"; sed -n 1,3p /tmp/ipf.log; w=1; }
    done
  done
done
[ $w = 0 ] && ok "widow: totals keep the last item (9 presets on their default layout x 18 cases)"
