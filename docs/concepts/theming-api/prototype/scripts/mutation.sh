#!/bin/sh
# CI mutation test: every frozen token must change the render of a built-in look
# (concept §3.2: a token is frozen only if a built-in part or preset reads it).
# Usage: sh scripts/mutation.sh [token ..]   (default: every token below)
set -u
fail=0
mkdir -p out/mut
rm -f out/mut/base-*.txt
# Built-in looks whose render must change (a token is live when ANY of them changes).
# "rail" = classic with a dark letterhead (exercises the logo plate on a dark surface);
# "technical" and "prestige" draw colors.accent-text (title word / section markers;
# key labels, column heads, the payable label).
LOOKS="classic corporate rail technical prestige"
# Frozen tokens and their built-in consumer (keep this list explicit: the merge
# stage reads it to see which consumer lives where).
#   colors.primary-text  presets corporate (title colour, kickers, sender name), elegant (title,
#                        letterhead), compact (title colour)
#   fonts.label          parts references, reference-list, sender-details, items-table header, bank-details labels
#   fonts.numeric        parts references/reference-list values, items-table figures, totals values,
#                        bank-details IBAN/reference, footer legal ids and IBAN, continuation number
#   spacing.leading      frame: paragraph leading of the body flow; items-table cells
#   radii.small          part totals: radius of options.totals.fill; preset corporate: payable bar
#   radii.medium         part logo: corner radius of the light plate on a dark surface (rail)
#   colors.accent-text   presets technical (document word, `// SECTION` markers) and prestige
#                        (column heads, "Bill to", payable label)
TOKENS="colors.primary colors.on-primary colors.primary-text colors.accent colors.text colors.text-muted colors.border colors.tint colors.background
  fonts.body fonts.heading fonts.label fonts.numeric fonts.number-width sizes.body sizes.small sizes.fine sizes.large sizes.title weights.strong
  strokes.hairline strokes.thin strokes.regular strokes.thick spacing.small spacing.medium spacing.leading radii.small radii.medium colors.accent-text"
# Frozen by the 0.5.0 contract, consumer still to land (printed to stderr, never
# fails). Remove a token here as soon as its consumer is merged; the script says so.
PENDING=""
[ $# -gt 0 ] && TOKENS="$*"
h() { rm -f out/mut/*.png; typst compile --root . "$@" "out/mut/p-{p}.png" --ppi 40 2>/dev/null || { echo "compile failed: $*" >&2; exit 2; }; cat out/mut/*.png | md5sum | cut -c1-32; }
# changed <extra args..>: 0 when the mutated render differs from the base under any look
changed() {
  for look in $LOOKS; do
    # unmutated renders are computed once per look and font (cached in out/mut)
    key="out/mut/base-$look-$(echo "$*" | tr -c 'a-zA-Z0-9
' '_').txt"
    [ -f "$key" ] || h --input look=$look "$@" tests/mutation.typ > "$key"
    b=$(cat "$key")
    m=$(h --input look=$look --input tok=$tok "$@" tests/mutation.typ)
    [ "$b" != "$m" ] && return 0
  done
  return 1
}
for tok in $TOKENS; do
  pending=0; case " $PENDING " in *" $tok "*) pending=1;; esac
  if [ $tok = fonts.number-width ]; then
    # needs a font with both figure styles (Liberation Sans has tabular digits only)
    if changed --input "font=Libertinus Serif"; then live=1; else live=0; fi
  else
    if changed; then live=1; else live=0; fi
  fi
  if [ $live = 1 ] && [ $pending = 1 ]; then echo "ok   $tok (listed as PENDING, but live now: remove it from PENDING)"
  elif [ $live = 1 ]; then echo "ok   $tok"
  elif [ $pending = 1 ]; then echo "PENDING $tok: frozen token without a built-in consumer yet (see scripts/mutation.sh)" >&2
  else echo "DEAD $tok"; fail=1; fi
done
exit $fail
