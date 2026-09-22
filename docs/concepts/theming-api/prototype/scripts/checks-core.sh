#!/bin/sh
# Core-stage checks (merged prototype): layout by sender region, and
# validation: none + zugferd attaches the XML even when data is missing.
# Sourced by scripts/run-all.sh (uses its c/ok/bad helpers and $fail).
for look in classic corporate plain; do
  for r in de at ch fr it es gb us nl; do
    c "layout auto $look/$r" --input look=$look --input region=$r tests/layout-region.typ out/lr.pdf
  done
done
c "layout explicit wins (us sender, din-5008-b)" --input region=us --input explicit=1 tests/layout-region.typ out/lr.pdf
# off means off: under none the factur-x.xml is attached although data is missing;
# under draft the same document withholds it
if typst compile --root . --pdf-standard a-3b --input level=none tests/validation/draft.typ out/v-none-zf.pdf >/tmp/ipf.log 2>&1 \
  && grep -a -q 'factur-x.xml' out/v-none-zf.pdf \
  && typst compile --root . --pdf-standard a-3b tests/validation/draft.typ out/v-draft-zf.pdf >/tmp/ipf.log 2>&1 \
  && ! grep -a -q 'factur-x.xml' out/v-draft-zf.pdf; then
  ok "none attaches factur-x.xml with missing data; draft withholds it"
else
  bad "none attaches factur-x.xml with missing data; draft withholds it"; sed -n 1,6p /tmp/ipf.log
fi
