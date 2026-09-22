#!/bin/sh
# compat-014: render the parity set with the `typst` on PATH into $1 (a directory).
# FONTS=fixed (default): --ignore-system-fonts + parity/fonts (Liberation Sans/Mono copied from
#   Windows) so both compilers see byte-identical fonts; FONTS=system: whatever the host has.
set -u
D=$1; PPI=${PPI:-90}
mkdir -p "$D"
if [ "${FONTS:-fixed}" = fixed ]; then F="--ignore-system-fonts --font-path parity/fonts"; else F=""; fi
r() { name=$1; shift; typst compile --root . $F "$@" "$D/$name-{p}.png" --ppi $PPI >"$D/$name.log" 2>&1 || echo "FAIL $name: $(grep -m1 error "$D/$name.log")"; }
for look in classic corporate minimal plain; do
  for lay in din-5008-a din-5008-b us-letter-10 a4-digital us-letter-digital sn-010130-right sn-010130-left plain; do
    r "m-$look-$lay" --input look=$look --input layout=$lay tests/matrix.typ
  done
done
for p in p1 p4 p6 p8 scope; do r "w-$p" --input p=$p tests/walk.typ; done
for m in print pdf einvoice; do r "p2-$m" --input output=$m tests/p2-stationery.typ; done
r third --package-path tests/pkgs tests/third-party.typ
for f in tests/doc/*.typ; do case $f in *prelude*|*corporate*) continue;; esac; r "doc-$(basename $f .typ)" --package-path tests/pkgs "$f"; done
for look in classic corporate plain minimal; do r "ua-$look" --input look=$look tests/compat/ua.typ; done
echo done
