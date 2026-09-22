#!/bin/sh
# presets-display checks: the `bold` and `compact` presets (src/theming/looks/).
# Sourced by scripts/run-all.sh (uses its c/ok/bad helpers and $fail).
# pages <glob-prefix>: number of PNG pages a render produced
pd_pages() { ls "$1"-*.png 2>/dev/null | wc -l | tr -d ' '; }
# pd_expect_pages <name> <want> <out-prefix> <compile args..>
pd_expect_pages() {
  name=$1; want=$2; prefix=$3; shift 3
  rm -f "$prefix"-*.png
  if typst compile --root . "$@" "$prefix-{p}.png" --ppi 30 >/tmp/ipf.log 2>&1; then
    got=$(pd_pages "$prefix")
    if [ "$got" = "$want" ]; then ok "$name ($got page(s))"; else bad "$name: $got page(s), want $want"; fi
  else bad "$name"; sed -n 1,6p /tmp/ipf.log; fi
}
mkdir -p out/pd
# 1. look x layout: scripts/checks-presets.sh (every preset, every layout)
# 2. a 4-item invoice fits on ONE page on the preset's default layout and on DIN 5008 A
pd_expect_pages "bold n=4 fits a4-digital" 1 out/pd/n4-bold-a4d --input look=bold --input layout=a4-digital tests/matrix.typ
pd_expect_pages "bold n=4 fits din-5008-a" 1 out/pd/n4-bold-dina --input look=bold --input layout=din-5008-a tests/matrix.typ
pd_expect_pages "compact n=4 fits a4-dense" 1 out/pd/n4-compact-dense --input look=compact --input layout=a4-dense tests/matrix.typ
pd_expect_pages "compact n=4 fits din-5008-a" 1 out/pd/n4-compact-dina --input look=compact --input layout=din-5008-a tests/matrix.typ
# layout auto (German sender: bold -> a4-digital, compact -> a4-dense; tests/looks-kit.typ asserts the mapping)
pd_expect_pages "bold n=4 fits (layout auto)" 1 out/pd/n4-bold-auto --input preset=bold tests/presets-display.typ
pd_expect_pages "compact n=4 fits (layout auto)" 1 out/pd/n4-compact-auto --input preset=compact tests/presets-display.typ
pd_expect_pages "compact: 30 rows, totals, bank and closing on one page (a4-dense)" 1 out/pd/dense30 --input preset=compact --input n=30 tests/presets-display.typ
# 3. three pages: continuation header, page labels, repeated table header
pd_expect_pages "bold 3-page invoice" 3 out/pd/3p-bold --input preset=bold --input n=60 tests/presets-display.typ
pd_expect_pages "compact 3-page invoice" 3 out/pd/3p-compact --input preset=compact --input n=110 tests/presets-display.typ
# 4. the payable label: poster block and totals bar name the same amount
pd_labels() { typst query --root . "$@" tests/presets-display.typ "<pd-label>" --field value 2>/dev/null | tr -d ' \n'; }
got=$(pd_labels --input preset=bold --input deposit=1)
case "$got" in *amount-due*amount-due*) ok "bold: block and bar say 'Fälliger Betrag' after a deposit";; *) bad "bold payable label after a deposit: $got";; esac
got=$(pd_labels --input preset=bold)
case "$got" in *amount-due*) bad "bold payable label without deposit: $got";; *total*total*) ok "bold: block and bar say 'Gesamtbetrag' without a deposit";; *) bad "bold payable label without deposit: $got";; esac
# 5. contrast: checks(min-contrast: 4.5) incl. the look's checks.pairs, under strict
for seed in "" 111111 ffd400 0f766e; do
  extra=""; [ -n "$seed" ] && extra="--input seed=$seed"
  c "bold contrast 4.5 strict ${seed:-default}" --input invoice-pro-validation=strict --input check=1 $extra tests/gallery/bold.typ "out/pd/ct-bold-{p}.png" --ppi 30
  c "compact contrast 4.5 strict ${seed:-default}" --input invoice-pro-validation=strict --input check=1 $extra tests/gallery/compact.typ "out/pd/ct-compact-{p}.png" --ppi 30
done
# the declared pair is checked: a seed whose disc fails must be reported by name
cat > out/pd/disc.typ <<'EOF'
#import "/src/lib.typ": *
#show: invoice.with(
  theme: theme.bold.with(theme.custom.colors(primary: rgb("#777777"), on-primary: white), theme.custom.checks(min-contrast: 4.5)),
  sender: (name: "A GmbH", address: "Weg 1", city: "20457 Hamburg", vat-id: "DE123456789"),
  recipient: (name: "B AG", address: "Weg 2", city: "80331 München"),
  invoice-nr: "1",
)
#line-items[#item([X], price: 10)]
EOF
msg=$(typst compile --root . --input invoice-pro-validation=strict out/pd/disc.typ out/pd/disc.pdf 2>&1 | awk -f scripts/panic-text.awk)
case "$msg" in *"checks::pairs::bold-disc"*) ok "bold: the disc pair (checks.pairs::bold-disc) is checked";; *) bad "bold disc pair"; echo "  got: $msg";; esac
# 6. PDF standards: ZUGFeRD under PDF/A-3b, an image logo with alt text under PDF/UA-1
c "bold a-3b + zugferd" --pdf-standard a-3b --input zugferd=1 tests/gallery/bold.typ out/pd/bold-a3b.pdf
c "compact a-3b + zugferd" --pdf-standard a-3b --input zugferd=1 tests/gallery/compact.typ out/pd/compact-a3b.pdf
c "bold ua-1 (image logo with alt)" --pdf-standard ua-1 tests/gallery/bold.typ out/pd/bold-ua1.pdf
c "compact ua-1 (image logo with alt)" --pdf-standard ua-1 --input logo=image tests/gallery/compact.typ out/pd/compact-ua1.pdf
# 7. embedded fonts only (the chains end in Libertinus Serif / DejaVu Sans Mono)
c "bold --ignore-system-fonts" --ignore-system-fonts tests/gallery/bold.typ "out/pd/nf-bold-{p}.png" --ppi 40
c "compact --ignore-system-fonts" --ignore-system-fonts tests/gallery/compact.typ "out/pd/nf-compact-{p}.png" --ppi 40
# 8. validation draft: missing number and tax ID render as markers inside the looks; strict panics
c "bold draft markers" --input preset=bold --input broken=1 tests/presets-display.typ "out/pd/draft-bold-{p}.png" --ppi 40
c "compact draft markers" --input preset=compact --input broken=1 tests/presets-display.typ "out/pd/draft-compact-{p}.png" --ppi 40
for p in bold compact; do
  if typst compile --root . --input invoice-pro-validation=strict --input preset=$p --input broken=1 tests/presets-display.typ out/pd/strict.pdf >/dev/null 2>&1; then
    bad "$p strict must panic on missing data"
  else ok "$p strict panics on missing data"; fi
done
# 9. long document words step down inside the poster block; the gallery renders on its layouts
c "bold long title word" --input title=Abschlagsrechnung --input deposit=1 tests/gallery/bold.typ "out/pd/long-{p}.png" --ppi 40
c "bold long title on sn-010130-right" --input title=Abschlagsrechnung --input layout=sn-010130-right tests/gallery/bold.typ "out/pd/long-sn-{p}.png" --ppi 40
for lang in de fr; do c "bold gallery $lang" --input lang=$lang tests/gallery/bold.typ "out/pd/g-bold-$lang-{p}.png" --ppi 40; done
c "compact gallery en on us-letter-dense" --input lang=en --input layout=us-letter-dense tests/gallery/compact.typ "out/pd/g-compact-en-{p}.png" --ppi 40
# 10. kit helpers
c "looks kit" tests/looks-kit.typ out/pd/kit.pdf
