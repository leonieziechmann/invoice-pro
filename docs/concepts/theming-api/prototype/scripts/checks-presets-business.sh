#!/bin/sh
# Presets stage (business): corporate (replaces modern) and boxed, plus the core
# widow rule (the totals never start a page alone). Sourced by scripts/run-all.sh
# (uses its c/ok/bad helpers and $fail).
LAYS="din-5008-a din-5008-b us-letter-10 a4-digital us-letter-digital sn-010130-right sn-010130-left a4-window-right a4-window-left plain a4-sidebar us-letter-sidebar"
# (matrix and layout-by-region for every preset: scripts/checks-presets.sh)
# WCAG AA on every layout with the preset's own checks.pairs, strict (an issue panics);
# three seeds: the preset's own, a pale brand, a saturated brand
for look in corporate boxed; do
  for lay in auto $LAYS; do
    for col in none "#9fd8f5" "#c2185b"; do
      c "contrast 4.5 $look/$lay/$col" --input invoice-pro-validation=strict --input look=$look --input layout=$lay --input color=$col tests/preset-checks.typ out/pc.pdf
    done
  done
  # negative: a dark tint must fail (a pair or a core pair names it)
  if typst compile --root . --input invoice-pro-validation=strict --input look=$look --input tint=#333333 tests/preset-checks.typ out/pc.pdf >/dev/null 2>&1; then
    bad "contrast $look: a dark tint must fail the checks"
  else ok "contrast $look: a dark tint fails the checks"; fi
done
# a 4-item invoice fits on ONE page on the preset's default layout (German sender)
for look in corporate boxed; do
  rm -f out/fit-$look-*.png
  if typst compile --root . --input look=$look --input n=4 tests/preset-checks.typ "out/fit-$look-{p}.png" --ppi 30 >/tmp/ipf.log 2>&1 && [ ! -f out/fit-$look-2.png ]; then
    ok "n=4 fits on 1 page ($look, default layout)"
  else bad "n=4 fits on 1 page ($look, default layout)"; fi
done
# 3-page invoice: continuation header, repeated table header, page numbers
# (boxed: 52 items, 3 pages for 44..70 since its tighter form rows)
for ln in corporate:55 boxed:52; do
  look=${ln%%:*}
  rm -f out/p3-$look-*.png
  if typst compile --root . --input look=$look --input n=${ln##*:} tests/preset-checks.typ "out/p3-$look-{p}.png" --ppi 40 >/tmp/ipf.log 2>&1 && [ -f out/p3-$look-3.png ] && [ ! -f out/p3-$look-4.png ]; then
    ok "3-page invoice ($look)"
  else bad "3-page invoice ($look)"; sed -n 1,6p /tmp/ipf.log; fi
done
# PDF/A-3b with ZUGFeRD (XML attached), PDF/UA-1 with an image logo carrying alt text
for look in corporate boxed; do
  if typst compile --root . --pdf-standard a-3b --input look=$look --input zugferd=1 tests/preset-checks.typ out/pc-a3b.pdf >/tmp/ipf.log 2>&1 && grep -a -q 'factur-x.xml' out/pc-a3b.pdf; then
    ok "a-3b + zugferd ($look)"
  else bad "a-3b + zugferd ($look)"; sed -n 1,6p /tmp/ipf.log; fi
  c "ua-1 image logo with alt ($look)" --pdf-standard ua-1 --input look=$look --input logo=image tests/preset-checks.typ out/pc-ua.pdf
  c "draft renders ($look)" --input look=$look --input lang=de tests/validation/draft.typ "out/v-draft-$look-{p}.png" --ppi 40
  c "ignore-system-fonts ($look)" --ignore-system-fonts tests/gallery/$look.typ "out/gal-nofonts-$look-{p}.png" --ppi 40
done
# galleries: default layout (German sender) and one other; e-invoice gallery under a-3b
c "gallery corporate (auto: a4-sidebar)" tests/gallery/corporate.typ "out/gal-corporate-{p}.png" --ppi 40
c "gallery corporate (din-5008-a)" --input layout=din-5008-a tests/gallery/corporate.typ "out/gal-corporate-din-{p}.png" --ppi 40
c "gallery boxed (auto: din-5008-a)" tests/gallery/boxed.typ "out/gal-boxed-{p}.png" --ppi 40
c "gallery boxed (a4-digital)" --input layout=a4-digital tests/gallery/boxed.typ "out/gal-boxed-dig-{p}.png" --ppi 40
c "gallery boxed a-3b + zugferd" --pdf-standard a-3b --input zugferd=1 tests/gallery/boxed.typ out/gal-boxed.pdf
c "gallery corporate ua-1" --pdf-standard ua-1 tests/gallery/corporate.typ out/gal-corporate.pdf
# widow rule: the last item and the totals share a page, around every page boundary,
# with and without a closing group subtotal
w=0
for look in classic corporate boxed; do
  for lay in din-5008-a a4-digital; do
    for n in 14 15 16 17 18 19 20 21 22; do
      for g in 0 1; do
        typst compile --root . --input look=$look --input layout=$lay --input n=$n --input group=$g tests/widow.typ out/w.pdf >/tmp/ipf.log 2>&1 || { bad "widow $look/$lay n=$n group=$g"; sed -n 1,3p /tmp/ipf.log; w=1; }
      done
    done
  done
done
[ $w = 0 ] && ok "widow: totals keep the last item (classic, corporate, boxed x 2 layouts x 18 cases)"
