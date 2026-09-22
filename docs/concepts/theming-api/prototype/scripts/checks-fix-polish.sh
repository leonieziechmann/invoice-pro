#!/bin/sh
# fix-polish checks: prestige/elegant letterheads on every layout, API hygiene of
# the public modules, the localised draft report (O5) and the doc logo assets.
# Sourced by scripts/run-all.sh (uses its c/ok/bad helpers and $fail).
mkdir -p out/fp
# 1. serif letterhead: arrangement unit test, then stress renders (long name,
#    wide and tall logos on the on-dark plate) on every layout
c "polish: serif letterhead fits its box, logo column never squeezed" tests/polish/arrange.typ out/fp/arrange.pdf
FP_LAYOUTS="din-5008-a din-5008-b us-letter-10 a4-digital us-letter-digital sn-010130-right sn-010130-left a4-window-right a4-window-left plain a4-sidebar us-letter-sidebar a4-band us-letter-band a4-dense us-letter-dense"
r=0
for look in prestige elegant; do
  for lay in $FP_LAYOUTS; do
    for lg in wide tall; do
      typst compile --root . --input look=$look --input layout=$lay --input logo=$lg tests/polish/letterhead.typ out/fp/lh.pdf >/tmp/ipf.log 2>&1 || { bad "polish letterhead $look/$lay/$lg"; sed -n 1,4p /tmp/ipf.log; r=1; }
    done
  done
done
[ $r = 0 ] && ok "polish: serif letterheads, long name, wide/tall logo (2 looks x 16 layouts x 2 logos)"
# 2. API hygiene: exported names of every public module == the documented lists
c "polish: public module exports == documented lists" tests/polish/exports.typ out/fp/exports.pdf
# 3. localised draft report: static texts for every key in five languages, and a
#    real draft (IBAN, logo alt, fine size, contrast) rendered per language
for l in de en fr it es; do
  c "polish: draft report in $l (IBAN, logo alt, fine size, contrast)" --input lang=$l tests/polish/report-lang.typ "out/fp/report-$l-{p}.png" --ppi 40
done
# every issue key passed in src/ has texts (the list in tests/polish/report-lang.typ)
used=$(grep -rhoE 'key: "[a-z-]+"' src/components src/theming src/validation src/zugferd | sed 's/key: "//; s/"//' | sort -u | tr '\n' ' ')
listed=$(sed -n '/^#let issue-keys = (/,/^)/p' tests/polish/report-lang.typ | grep -oE '"[a-z-]+"' | tr -d '"' | sort -u | tr '\n' ' ')
if [ "$used" = "$listed" ]; then ok "polish: issue keys in src == localised keys ($(echo $used | wc -w | tr -d ' '))"; else bad "polish: issue keys differ: src [$used] vs test [$listed]"; fi
# 4. doc logos are logo-sized marks (not the full-page letterhead fixture)
r=0
for f in acme logo sw; do
  if grep -q 'height="297mm"' tests/doc/$f.svg; then bad "polish: tests/doc/$f.svg is a full page"; r=1; fi
done
cmp -s tests/logo-acme.svg tests/doc/acme.svg && cmp -s tests/logo-mark.svg tests/doc/logo.svg && cmp -s tests/logo-sw.svg tests/doc/sw.svg || { bad "polish: tests/doc logos differ from their sources (run scripts/make-doc-tests.py)"; r=1; }
[ $r = 0 ] && ok "polish: doc logos are logo assets (acme, logo, sw)"
