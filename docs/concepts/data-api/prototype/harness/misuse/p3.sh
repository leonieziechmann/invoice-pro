#!/bin/bash
# P3: no sample leaks (draft markers, XML withheld, strict exit 1) and every
# R7 panic with its fix; skeleton misuse panics. usage: p3.sh TYPST
T=$1; cd "$(dirname "$0")"; U=$(cd ../.. && pwd); O=../out/p3-$(basename $T); mkdir -p $O; fails=0
V=$($T --version | cut -d' ' -f2)
ok() { echo "PASS $V $*"; }; no() { echo "FAIL $V $*"; fails=$((fails+1)); }
C="--root $U --creation-timestamp 1767225600 --pdf-standard a-3b"
SAMPLES="MUSTER-0001|Erika Mustermann|Leerung Restmüll 120 l|Grundversorgung|Musterbank"
for b in no-invoice-nr no-date no-recipient no-items; do
  f=../data/broken-$b.json
  $T compile $C ../examples/skeleton.typ $O/$b.pdf --input invoice-pro-data-file=$f 2>$O/$b.err
  txt=$(pdftotext $O/$b.pdf - 2>/dev/null); att=$(pdfdetach -list $O/$b.pdf 2>/dev/null | head -1)
  leak=$(echo "$txt" | grep -cE "$SAMPLES")
  badge=$(echo "$txt" | grep -m1 -o "ENTWURF[^\n]*")
  marker=$(echo "$txt" | grep -o "‹fehlt[^›]*›" | sort -u | tr '\n' ' ')
  [ "$att" = "0 embedded files" ] && [ "$leak" = 0 ] && [ -n "$badge" ] && ok "missing $b: draft [$badge] markers [$marker] XML withheld, 0 sample strings" || no "missing $b: att=$att leak=$leak badge=$badge"
  $T compile $C ../examples/skeleton.typ $O/$b-strict.pdf --input invoice-pro-data-file=$f --input invoice-pro-validation=strict >/dev/null 2>$O/$b-strict.err
  e=$?; [ $e = 1 ] && [ ! -f $O/$b-strict.pdf ] && ok "missing $b: strict exit 1 ($(grep -m1 -o 'invoice::[a-z-]* is missing\|no line items\|invoice data[^;.]*' $O/$b-strict.err | head -1))" || no "missing $b strict exit=$e"
done
# the many-problem file: draft lists every problem, strict panics with all
$T compile $C ../examples/skeleton.typ $O/bad.pdf --input invoice-pro-data-file=../data/bad.json 2>/dev/null
n=$(pdftotext $O/bad.pdf - | grep -m1 -o "ENTWURF · [0-9]* Probleme"); [ -n "$n" ] && ok "bad.json: $n" || no "bad.json draft"
$T compile $C ../examples/skeleton.typ $O/bad-s.pdf --input invoice-pro-data-file=../data/bad.json --input invoice-pro-validation=strict >/dev/null 2>$O/bad-s.err; [ $? = 1 ] && ok "bad.json strict exit 1: $(grep -c 'invoice data' $O/bad-s.err) data messages" || no "bad strict"
panic() { # name expected-substring compile-args...
  local n=$1 want=$2; shift 2
  $T compile $C "$@" $O/$n.pdf >/dev/null 2>$O/$n.err; local e=$?
  if [ $e = 1 ] && grep -q -- "$want" $O/$n.err; then ok "panic $n: $(grep -m1 '^error' $O/$n.err | cut -c1-170)"; else no "panic $n exit=$e: $(grep -m1 '^error' $O/$n.err | cut -c1-200)"; fi
}
J="$(cat ../data/2026-0042.json)"
panic file-without-read "invoice-data.load(read: p => read(p, encoding: none))" zero.typ --input invoice-pro-data-file=../data/2026-0042.json
panic two-inputs "given twice" ../examples/skeleton.typ --input invoice-pro-data="$J" --input invoice-pro-data-file=../data/2026-0042.json
panic explicit-plus-input "given twice" explicit.typ --input invoice-pro-data="$J"
panic record-plus-input "given twice" record.typ --input invoice-pro-data-file=../data/2026-0042.json
panic none-plus-input "data: none" none.typ --input invoice-pro-data="$J"
panic none-plus-file "data: none" none.typ --input invoice-pro-data-file=../data/2026-0042.json
panic str-path "not a JSON object" zero.typ --input invoice-pro-data=data/2026-0042.json
panic str-path-umlaut "not a JSON object" zero.typ --input "invoice-pro-data=/home/jürgen/Rechnungen/2026/Gebührenbescheid-Müllgebühr-0042.json"
# near misses of the data keys (round 1): nobody would read them
for k in invoice-pro-data-fil invoice-pro-datafile invoice-pro-data-file. INVOICE-PRO-DATA-FILE invoice_pro_data_file; do
  panic "near-miss-$k" "is not a key invoice-pro reads" ../examples/skeleton.typ --input "$k=../data/2026-0042.json"
done
panic near-miss-none "is not a key invoice-pro reads" none.typ --input invoice-pro-data-fil=../data/2026-0042.json
panic format-major "invoice-pro/2" major2.typ
panic two-markers "at most one" two-markers.typ
panic two-markers-data "at most one" two-markers.typ --input invoice-pro-data="$J"
panic marker-in-group "direct child of \`line-items\`" marker-in-group.typ
# zero-code inline hydration works
$T compile $C zero.typ $O/zero-inline.pdf --input invoice-pro-data="$J" 2>/dev/null && pdftotext $O/zero-inline.pdf - | grep -q "Rechnung 2026-0042" && ok "zero-code skeleton hydrates from inline JSON" || no "zero inline"
# coverage: items without line-items, payment without payment(..)
$T compile $C no-binding.typ $O/no-binding.pdf --input invoice-pro-data-file=../data/2026-0042.json --input invoice-pro-validation=strict >/dev/null 2>$O/nb.err
grep -q "no \`line-items\`" $O/nb.err && grep -q "no \`payment(..)\` block" $O/nb.err && ok "coverage issues: schema/items and schema/payment" || no "coverage"
# blank required values (round 1): spaces as invoice-nr, a recipient named by empty lines
printf '%s' "$J" | python3 -c 'import json,sys; d=json.load(sys.stdin); d["invoice-nr"]="   "; d["recipient"]["name"]=["",""]; print(json.dumps(d))' > $O/blank.json
$T compile $C ../examples/skeleton.typ $O/blank-s.pdf --input invoice-pro-data="$(cat $O/blank.json)" --input invoice-pro-validation=strict >/dev/null 2>$O/blank-s.err
[ $? = 1 ] && grep -q "invoice-nr is missing" $O/blank-s.err && grep -q "recipient" $O/blank-s.err && ok "blank invoice-nr and recipient name: strict exit 1 with the problem list" || no "blank required"
echo "failures: $fails"
