#!/bin/sh
# api-body checks: totals row model (view.totals.rows / payable, both tax modes,
# 0 % removed in measure, prepayments and amount due), the payment sentence after
# prepayments, bank reference and grouped IBAN, items-table knobs (header-style,
# row-rule, row-inset), totals fill/colour/min-width and the item keep-together.
# Sourced by scripts/run-all.sh (uses its c/ok/bad helpers and $fail).
for k in excl incl plain noref style rule inset keep; do
  c "api-body $k" --input case=$k tests/api-body.typ "out/ab-$k-{p}.png" --ppi 60
done
# every knob changes the render against the same data without it
hp() { cat out/ab-$1-*.png | md5sum | cut -c1-32; }
for k in style rule inset; do
  if [ "$(hp $k)" != "$(hp plain)" ]; then ok "api-body knob $k changes the render"; else bad "api-body knob $k changes the render"; fi
done
# totals.color on totals.fill is a checked contrast pair (strict panics, draft renders)
cat > out/ab-contrast.typ <<'EOF'
#import "/src/lib.typ": *
#show: invoice.with(
  theme: theme.classic.with(theme.custom.totals(fill: rgb("#1f2937"), color: rgb("#333333")), theme.custom.checks(min-contrast: 4.5)),
  sender: (name: "A GmbH", address: "Weg 1", city: "20457 Hamburg", vat-id: "DE123456789"),
  recipient: (name: "B AG", address: "Weg 2", city: "80331 München"),
  invoice-nr: "1",
)
#line-items[#item([X], price: 10)]
EOF
want="theme: options::totals::color on options::totals::fill has contrast"
msg=$(typst compile --root . --input invoice-pro-validation=strict out/ab-contrast.typ out/ab-contrast.pdf 2>&1 | awk -f scripts/panic-text.awk)
case "$msg" in *"$want"*) ok "api-body totals.color/fill contrast pair (strict)";; *) bad "api-body totals.color/fill contrast pair (strict)"; echo "  got: $msg";; esac
c "api-body contrast pair renders under draft" --input invoice-pro-validation=draft out/ab-contrast.typ out/ab-contrast.pdf
