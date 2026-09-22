#!/bin/sh
# api-frame checks: footer fit and clearance, identity without repr(), frame view
# additions, area/arrange extensions and frame part fixes.
# Sourced by scripts/run-all.sh (uses its c/ok/bad helpers and $fail).

# 1. footer fit: on every layout, classic and corporate, a 4-line registration block ends
#    at least footer-clearance (5 mm) above the sheet edge on pages 1 and 2 (strict)
for lay in din-5008-a din-5008-b us-letter-10 a4-digital us-letter-digital sn-010130-right sn-010130-left a4-window-right a4-window-left plain; do
  for look in classic corporate; do
    c "footer clearance $look/$lay" --input invoice-pro-validation=strict --input look=$look --input layout=$lay tests/api-frame/footer-fit.typ "out/af-ff-$look-$lay-{p}.png" --ppi 60
  done
done
# ... with only the embedded fonts (the chains fall back to Libertinus / New Computer Modern)
for lay in din-5008-a us-letter-10 a4-digital; do
  c "footer clearance, embedded fonts only, $lay" --ignore-system-fonts --input invoice-pro-validation=strict --input layout=$lay tests/api-frame/footer-fit.typ out/af-ff.pdf
done
# negative control: a too small explicit margin trips the position probe under none,
# panics under strict (lint) and renders under draft (overflow marker, report)
if typst compile --root . --input invoice-pro-validation=none --input margin=24 tests/api-frame/footer-fit.typ out/af-ff.pdf >/dev/null 2>&1; then
  bad "footer probe detects a footer below the clearance (margin 24mm, none)"
else ok "footer probe detects a footer below the clearance (margin 24mm, none)"; fi
msg=$(typst compile --root . --input invoice-pro-validation=strict --input margin=24 --input check=0 tests/api-frame/footer-fit.typ out/af-ff.pdf 2>&1 | awk -f scripts/panic-text.awk)
case "$msg" in *"theme::layout::areas::footer is "*"mm footer-clearance"*) ok "explicit margin too small: strict panics (lint/footer-fit)";; *) bad "explicit margin too small: strict panics (lint/footer-fit)"; echo "  got: $msg";; esac
c "explicit margin too small: draft renders with the overflow marker" --input margin=24 --input check=0 tests/api-frame/footer-fit.typ "out/af-ff-draft-{p}.png" --ppi 60

# 2. identity check after layout: responsive and context titles pass under strict;
#    a number that is only measured, or a missing date, is still found
for m in responsive context; do
  c "identity: $m title passes under strict" --input invoice-pro-validation=strict --input mode=$m tests/api-frame/identity.typ "out/af-id-$m-{p}.png" --ppi 60
done
for pair in "measured:the invoice number (2026-0142) does not appear" "date:the invoice date ("; do
  m=${pair%%:*}; want=${pair#*:}
  msg=$(typst compile --root . --input invoice-pro-validation=strict --input mode=$m tests/api-frame/identity.typ out/af-id.pdf 2>&1 | awk -f scripts/panic-text.awk)
  case "$msg" in *"$want"*) ok "identity: $m title is rejected";; *) bad "identity: $m title is rejected"; echo "  got: $msg";; esac
done
c "identity: responsive title under draft (no finding)" --input mode=responsive tests/api-frame/identity.typ out/af-id.pdf
if typst query --root . --input mode=responsive tests/api-frame/identity.typ "<ip-issue>" 2>/dev/null | grep -q identity; then
  bad "identity: no draft finding for a responsive title"
else ok "identity: no draft finding for a responsive title"; fi

# 3. frame view additions, arrange (ctx, cells, area), page-number from auto, margin API
c "frame view: area.window/place/surface, payment.due, arrange cells, page 1 of n" --input invoice-pro-validation=strict tests/api-frame/view.typ "out/af-view-{p}.png" --ppi 60
c "continuation: separator, one-line subject; logo plate on a dark letterhead" --input invoice-pro-validation=strict tests/api-frame/continuation.typ "out/af-cont-{p}.png" --ppi 60

# 4. render pairs: the new fields and part fixes change the render (or provably do not)
ph() { rm -f out/af-pair-*.png; typst compile --root . "$@" "out/af-pair-{p}.png" --ppi 50 >/dev/null 2>&1 || { echo "compile failed: $*"; return 1; }; cat out/af-pair-*.png | md5sum | cut -c1-32; }
for pair in legal-fill:differ logo-dark:differ logo-light:same logo-alt:differ rows-gap:differ cell-align:differ par:differ radius:differ rule:differ rule-height:same page-from:differ; do
  k=${pair%%:*}; want=${pair#*:}
  a=$(ph --input case=$k --input v=a tests/api-frame/pairs.typ); b=$(ph --input case=$k --input v=b tests/api-frame/pairs.typ)
  if [ -z "$a" ] || [ -z "$b" ]; then bad "render pair $k"; continue; fi
  if [ "$want" = differ ] && [ "$a" != "$b" ]; then ok "render pair $k: renders differ"
  elif [ "$want" = same ] && [ "$a" = "$b" ]; then ok "render pair $k: renders identical"
  else bad "render pair $k (expected: $want)"; fi
done
