#!/bin/sh
# Audit-stage regressions. Sourced by scripts/run-all.sh (uses its c/ok/bad helpers and $fail).
mkdir -p out/audit
c "audit: plural units, dict item-ids, summary strings, embedded font chains" tests/audit.typ out/audit/audit.pdf
# invalid IBAN: a data issue, never a renderer panic
for look in classic corporate elegant soft compact boxed; do
  c "audit: invalid IBAN renders under draft ($look)" --input look=$look tests/audit/iban.typ "out/audit/iban-$look-{p}.png" --ppi 20
done
c "audit: invalid IBAN renders under none" --input invoice-pro-validation=none tests/audit/iban.typ out/audit/iban-none.pdf
msg=$(typst compile --root . --input invoice-pro-validation=strict tests/audit/iban.typ out/audit/iban.pdf 2>&1 | awk -f scripts/panic-text.awk)
case "$msg" in *"is not a valid IBAN"*) ok "audit: invalid IBAN panics under strict with the data message";; *) bad "audit: invalid IBAN under strict"; echo "  got: $msg";; esac
if typst compile --root . --pdf-standard a-3b --input zugferd=1 tests/audit/iban.typ out/audit/iban-a3b.pdf >/tmp/ipf.log 2>&1 && ! grep -a -q 'factur-x.xml' out/audit/iban-a3b.pdf; then
  ok "audit: invalid IBAN withholds the XML under draft"
else bad "audit: invalid IBAN withholds the XML under draft"; sed -n 1,4p /tmp/ipf.log; fi
msg=$(typst compile --root . tests/audit/profile.typ out/audit/profile.pdf 2>&1 | awk -f scripts/panic-text.awk)
case "$msg" in *"profile 'en16931' applied as 'xrechnung'"*) ok "audit: en16931 between German parties is named as applied XRechnung";; *) bad "audit: profile message"; echo "  got: $msg";; esac
