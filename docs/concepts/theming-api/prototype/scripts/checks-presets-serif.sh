#!/bin/sh
# presets-serif checks: the serif family (elegant, prestige). Sourced by
# scripts/run-all.sh (uses its c/ok/bad helpers and $fail).
c "serif: layout by region, strict contrast under brand seeds, one parts family" tests/presets-serif.typ out/presets-serif.pdf
# (every layout, incl. the band layouts: scripts/checks-presets.sh)
# pages() <label> <expected> <typst args..>: renders PNGs and counts the pages
pages() {
  label=$1; want=$2; shift 2
  rm -rf out/pg; mkdir -p out/pg
  if typst compile --root . "$@" "out/pg/p-{p}.png" --ppi 20 >/tmp/ipf.log 2>&1; then
    n=$(ls out/pg | wc -l | tr -d ' ')
    if [ "$n" = "$want" ]; then ok "$label ($n pages)"; else bad "$label: expected $want pages, got $n"; fi
  else bad "$label"; sed -n 1,6p /tmp/ipf.log; fi
}
# a 4-item invoice fits on ONE page on the preset's default layout (and on DIN A/B)
pages "serif: elegant n=4 on its default layout (din-5008-b)" 1 --input look=elegant --input layout=din-5008-b tests/matrix.typ
pages "serif: elegant n=4 on din-5008-a" 1 --input look=elegant --input layout=din-5008-a tests/matrix.typ
pages "serif: prestige n=4 on its default layout (a4-band)" 1 --input look=prestige --input layout=a4-band tests/matrix.typ
pages "serif: prestige n=4 on din-5008-b" 1 --input look=prestige --input layout=din-5008-b tests/matrix.typ
# galleries: strict validation (identity check, 4.5:1 contrast incl. checks.pairs) on the default layout
pages "serif: elegant gallery strict (layout auto)" 2 --input level=strict tests/gallery/elegant.typ
pages "serif: prestige gallery strict (layout auto)" 1 --input level=strict tests/gallery/prestige.typ
# 3-page invoices: continuation header, page numbers, repeated table header
pages "serif: elegant 3-page invoice" 3 --input level=strict --input extra=30 tests/gallery/elegant.typ
# (extra=36: with the core widow rule the folio needs more lines to reach page 3)
pages "serif: prestige 3-page folio" 3 --input level=strict --input extra=36 tests/gallery/prestige.typ
# embedded fonts only (every chain ends in Libertinus Serif / DejaVu Sans Mono)
for g in elegant prestige; do
  c "serif: $g gallery, embedded fonts only" --ignore-system-fonts --input level=strict tests/gallery/$g.typ "out/g-$g-nofonts-{p}.png" --ppi 60
done
# PDF standards: a-3b with ZUGFeRD, ua-1 with image logos carrying alt text
c "serif: elegant a-3b + zugferd" --pdf-standard a-3b --input zugferd=1 --input level=strict tests/gallery/elegant.typ out/g-elegant-a3b.pdf
c "serif: prestige a-3b + zugferd" --pdf-standard a-3b --input zugferd=1 --input level=strict tests/gallery/prestige.typ out/g-prestige-a3b.pdf
c "serif: elegant ua-1 (image logo, alt)" --pdf-standard ua-1 --input logo=1 --input level=strict tests/gallery/elegant.typ out/g-elegant-ua1.pdf
c "serif: prestige ua-1 (image logos, alt; band)" --pdf-standard ua-1 --input level=strict tests/gallery/prestige.typ out/g-prestige-ua1.pdf
c "serif: prestige ua-1 (dark logo on its plate, din-5008-b)" --pdf-standard ua-1 --input logo=plate --input layout=din-5008-b --input level=strict tests/gallery/prestige.typ out/g-prestige-ua1-din.pdf
# validation: draft renders with markers in the serif parts (de, en)
for lv in elegant:de prestige:en; do
  c "serif: draft ${lv}" --input look=${lv%%:*} --input lang=${lv##*:} tests/validation/draft.typ "out/v-draft-${lv%%:*}-{p}.png" --ppi 60
done
