#!/bin/sh
# presets technical and soft (presets-grid stage). Sourced by scripts/run-all.sh
# (uses its c/ok/bad helpers and $fail).
c "presets-grid: contrast over brand seeds (strict), own pairs, part budget, kit" tests/presets-grid.typ out/presets-grid.pdf
for p in technical soft; do
  # (every layout and layout=auto: scripts/checks-presets.sh)
  # a 4-item invoice fits on ONE page on the preset's default layout
  rm -f out/pg-one-$p-*.png
  typst compile --root . --input look=$p --input layout=auto tests/matrix.typ "out/pg-one-$p-{p}.png" --ppi 20 >/dev/null 2>&1
  if [ -f out/pg-one-$p-1.png ] && [ ! -f out/pg-one-$p-2.png ]; then ok "presets-grid: $p n=4 fits one page (default layout)"; else bad "presets-grid: $p n=4 fits one page (default layout)"; fi
  c "presets-grid: gallery $p a-3b + zugferd" --pdf-standard a-3b --input zugferd=en16931 tests/gallery/$p.typ out/pg-$p-a3b.pdf
  c "presets-grid: gallery $p ua-1 (image logo with alt)" --pdf-standard ua-1 tests/gallery/$p.typ out/pg-$p-ua1.pdf
  c "presets-grid: gallery $p checks(min-contrast: 4.5), strict" --input checks=1 --input invoice-pro-validation=strict tests/gallery/$p.typ "out/pg-$p-checks-{p}.png" --ppi 30
  c "presets-grid: gallery $p embedded fonts only" --ignore-system-fonts tests/gallery/$p.typ "out/pg-$p-embedded-{p}.png" --ppi 30
  c "presets-grid: draft validation $p" --input look=$p --input lang=en tests/validation/draft.typ "out/pg-$p-draft-{p}.png" --ppi 30
  # multi-page: continuation header, repeated table header, page numbers
  rm -f out/pg-$p-long-*.png
  extra=28; [ $p = soft ] && extra=40
  typst compile --root . --input extra=$extra tests/gallery/$p.typ "out/pg-$p-long-{p}.png" --ppi 20 >/dev/null 2>&1
  if [ -f out/pg-$p-long-3.png ]; then ok "presets-grid: $p 3-page invoice"; else bad "presets-grid: $p 3-page invoice"; fi
done
# totals travel with the last item (table footer): the widow case of the design review
c "presets-grid: technical us-letter-10 gallery (totals with last row)" --input layout=us-letter-10 tests/gallery/technical.typ "out/pg-t-usl-{p}.png" --ppi 30
