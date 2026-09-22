#!/bin/sh
# Naming-stage checks (Q7 rename map). Sourced by scripts/run-all.sh (uses its c/ok/bad helpers and $fail).
c "naming: new vocabulary resolves, old names are gone" tests/naming.typ out/naming.pdf
# stationery "generated" (the old spelling of none) is misuse under every level
if typst compile --root . --input invoice-pro-validation=none --input case=41 tests/errors/err.typ out/err.pdf >/dev/null 2>&1; then
  bad "misuse case 41 (stationery \"generated\") must panic under none"
else
  ok "misuse case 41 (stationery \"generated\") panics under none"
fi
# old field names are rejected with the new names listed (strict merge)
cat > out/naming-old.typ <<'EOF'
#import "/src/lib.typ": *
#let c = sys.inputs.at("c")
#let p = (
  x: theme.custom.area("address", x: 20mm),
  brand: theme.custom.area("letterhead", brand: false),
  regions: (layout: (regions: (address: (width: 80mm))),),
  base: (tokens: (sizes: (base: 9pt)),),
  qr: (options: (bank-details: (qr: false)),),
).at(c)
#let _ = theme.resolve(theme.classic.with(p))
EOF
for pair in "x:has unknown key \`x\`. Allowed keys: place, pages, left, top, right, bottom" \
  "brand:has unknown key \`brand\`." \
  "regions:theme::layout has unknown key \`regions\`." \
  "base:theme::tokens::sizes has unknown key \`base\`. Allowed keys: body, small" \
  "qr:theme::options::bank-details has unknown key \`qr\`. Allowed keys: show-qr, qr-size"; do
  k=${pair%%:*}; want=${pair#*:}
  msg=$(typst compile --root . --input c=$k out/naming-old.typ out/naming-old.pdf 2>&1 | awk -f scripts/panic-text.awk)
  case "$msg" in *"$want"*) ok "old name \`$k\` rejected";; *) bad "old name \`$k\` rejected"; echo "  got: $msg";; esac
done
