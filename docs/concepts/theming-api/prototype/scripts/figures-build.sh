#!/bin/sh
# Final figure set of the concept document (phase 4b).
# Usage (from the prototype root): sh scripts/figures-build.sh [dest]   (default ../figures in the bundle)
# Renders pages into out/f4/, then builds the labelled sheets with tests/figures-sheets.typ.
set -eu
dest=${1:-}
if [ -z "$dest" ]; then
  # bundle layout (prototype/ next to README.md and figures/), else the scratch layout
  if [ -f ../README.md ] && [ -d ../figures ]; then dest=../figures; else dest=../bundle/figures; fi
fi
R=out/f4
mkdir -p $R/g $R/m $R/l $R/p $R/v $R/s $R/a "$dest"
PRESETS="classic plain corporate elegant prestige bold technical soft compact boxed"
LAYOUTS="din-5008-a din-5008-b a4-window-right a4-window-left sn-010130-right sn-010130-left us-letter-10 a4-digital us-letter-digital a4-band us-letter-band a4-sidebar us-letter-sidebar a4-dense us-letter-dense plain"
PPI=${PPI:-120}

# 1. gallery pages (industry data), page 1 of each preset
for p in $PRESETS; do
  rm -f $R/g/$p-*.png
  case $p in
    classic|plain) typst compile --root . --input preset=$p tests/figures-gallery.typ "$R/g/$p-{p}.png" --ppi 90 ;;
    *) typst compile --root . tests/gallery/$p.typ "$R/g/$p-{p}.png" --ppi 90 ;;
  esac
  cp $R/g/$p-1.png "$dest/preset-$p.png"
done

# 2. identical data (tests/matrix.typ), each preset on its own default layout
for p in $PRESETS; do
  typst compile --root . --input look=$p --input layout=auto tests/matrix.typ "$R/m/$p-auto-{p}.png" --ppi $PPI
done

# 3. every layout with the classic look
for l in $LAYOUTS; do
  typst compile --root . --input look=classic --input layout=$l tests/matrix.typ "$R/l/$l-{p}.png" --ppi $PPI
done

# 4. proof overlays of four window layouts
for l in din-5008-a sn-010130-right a4-window-right us-letter-10; do
  typst compile --root . --input layout=$l tests/proof.typ "$R/p/$l-{p}.png" --ppi 200
done

# 5. validation draft (page 1 + report page)
rm -f $R/v/*.png $R/s/*.png $R/a/*.png
typst compile --root . --input level=draft --input lang=de tests/validation/draft.typ "$R/v/draft-{p}.png" --ppi 150

# 6. stationery modes
for m in print pdf einvoice; do
  typst compile --root . --input output=$m --input n=26 tests/figures-stationery.typ "$R/s/p2-$m-{p}.png" --ppi 170
done

# 7. any format: third-party A5 sidebar layout + thermal roll
typst compile --root . --package-path tests/pkgs tests/doc/p9.typ "$R/a/p9-{p}.png" --ppi 150
typst compile --root . tests/doc/receipt.typ "$R/a/rc-{p}.png" --ppi 170

# 8. matrix subset: 5 presets x 4 layouts
for p in classic corporate prestige technical boxed; do
  for l in din-5008-a sn-010130-right us-letter-10 a4-digital; do
    typst compile --root . --input look=$p --input layout=$l tests/matrix.typ "$R/m/$p-$l-{p}.png" --ppi 110
  done
done

# sheets: rendered at high ppi, then reduced to a 256-colour palette (flat document
# art: visually lossless, about a third of the size) to stay below 600 KB each
sheet() { # name ppi
  typst compile --root . --input fig=$1 tests/figures-sheets.typ "$dest/fig-$1.png" --ppi $2
  python - "$dest/fig-$1.png" <<'PY'
import sys
from PIL import Image
f = sys.argv[1]
im = Image.open(f).convert("RGB")
im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(f, optimize=True)
PY
}
sheet presets ${PPI_PRESETS:-190}
sheet presets-industry ${PPI_INDUSTRY:-190}
sheet layouts ${PPI_LAYOUTS:-190} # 180 drops the first letter of SN body lines (resampling)
sheet proof ${PPI_PROOF:-220}
sheet validation ${PPI_VALIDATION:-220}
sheet stationery ${PPI_STATIONERY:-240}
sheet any-format ${PPI_ANY:-220}
sheet matrix ${PPI_MATRIX:-180}
ls -l "$dest"
