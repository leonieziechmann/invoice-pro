#!/bin/bash
# P3: fail safe and no sample leaks: a hydrated invoice with a problem stops
# by default (exit 1, every problem, the layout's findings too, the debug
# hint); the debug flag --input invoice-pro-validation=draft gives the draft
# (markers, XML withheld, no sample string); every R7 panic with its fix;
# skeleton misuse panics.
# usage: p3.sh TYPST
T=$1; cd "$(dirname "$0")"; U=$(cd ../.. && pwd); O=../out/p3-$(basename $T); mkdir -p $O; fails=0
V=$($T --version | cut -d' ' -f2)
ok() { echo "PASS $V $*"; }; no() { echo "FAIL $V $*"; fails=$((fails+1)); }
C="--root $U --creation-timestamp 1767225600 --pdf-standard a-3b"
SAMPLES="MUSTER-0001|Erika Mustermann|Leerung Restmüll 120 l|Grundversorgung|Musterbank"
DRAFT="--input invoice-pro-validation=draft"
HINT="To debug, render the draft with --input invoice-pro-validation=draft"
for b in no-invoice-nr no-date no-recipient no-items; do
  f=../data/broken-$b.json
  # the default: a hydrated invoice stops on any problem, with the hint
  $T compile $C ../examples/skeleton.typ $O/$b-default.pdf --input invoice-pro-data-file=$f >/dev/null 2>$O/$b-default.err
  e=$?; [ $e = 1 ] && [ ! -f $O/$b-default.pdf ] && grep -q "$HINT" $O/$b-default.err && ok "missing $b: the default stops, exit 1, with the debug hint ($(grep -m1 -o 'invoice::[a-z-]* is missing\|no line items\|invoice data[^;.]*' $O/$b-default.err | head -1))" || no "missing $b default exit=$e"
  $T compile $C ../examples/skeleton.typ $O/$b.pdf --input invoice-pro-data-file=$f $DRAFT 2>$O/$b.err
  txt=$(pdftotext $O/$b.pdf - 2>/dev/null); att=$(pdfdetach -list $O/$b.pdf 2>/dev/null | head -1)
  leak=$(echo "$txt" | grep -cE "$SAMPLES")
  badge=$(echo "$txt" | grep -m1 -o "ENTWURF[^\n]*")
  marker=$(echo "$txt" | grep -o "‹fehlt[^›]*›" | sort -u | tr '\n' ' ')
  [ "$att" = "0 embedded files" ] && [ "$leak" = 0 ] && [ -n "$badge" ] && ok "missing $b, draft flag: draft [$badge] markers [$marker] XML withheld, 0 sample strings" || no "missing $b: att=$att leak=$leak badge=$badge"
  $T compile $C ../examples/skeleton.typ $O/$b-strict.pdf --input invoice-pro-data-file=$f --input invoice-pro-validation=strict >/dev/null 2>$O/$b-strict.err
  e=$?; [ $e = 1 ] && [ ! -f $O/$b-strict.pdf ] && ok "missing $b: strict exit 1 ($(grep -m1 -o 'invoice::[a-z-]* is missing\|no line items\|invoice data[^;.]*' $O/$b-strict.err | head -1))" || no "missing $b strict exit=$e"
done
# the many-problem file: the default stops with every problem and the hint,
# the draft flag lists every problem, strict panics with all
$T compile $C ../examples/skeleton.typ $O/bad-d.pdf --input invoice-pro-data-file=../data/bad.json >/dev/null 2>$O/bad-d.err; e=$?
n=$(grep -o 'invoice data: ' $O/bad-d.err | wc -l)
[ $e = 1 ] && grep -q "found $n problems in the hydrated invoice" $O/bad-d.err && grep -q "$HINT" $O/bad-d.err && ok "bad.json default: exit 1, the stop lists $n problems and ends with the hint" || no "bad default exit=$e n=$n"
$T compile $C ../examples/skeleton.typ $O/bad.pdf --input invoice-pro-data-file=../data/bad.json $DRAFT 2>/dev/null
n=$(pdftotext $O/bad.pdf - | grep -m1 -o "ENTWURF · [0-9]* Probleme"); a=$(pdfdetach -list $O/bad.pdf 2>/dev/null | head -1); [ -n "$n" ] && [ "$a" = "0 embedded files" ] && ok "bad.json, draft flag: $n, $a" || no "bad.json draft [$n] [$a]"
$T compile $C ../examples/skeleton.typ $O/bad-s.pdf --input invoice-pro-data-file=../data/bad.json --input invoice-pro-validation=strict >/dev/null 2>$O/bad-s.err; [ $? = 1 ] && ok "bad.json strict exit 1: $(grep -o 'invoice data: ' $O/bad-s.err | wc -l) data messages" || no "bad strict"
# off means off: --input invoice-pro-validation=none renders without checks
$T compile $C ../examples/skeleton.typ $O/bad-n.pdf --input invoice-pro-data-file=../data/bad.json --input invoice-pro-validation=none >/dev/null 2>$O/bad-n.err && ! pdftotext $O/bad-n.pdf - | grep -q ENTWURF && ok "bad.json with the flag none: renders, no draft badge (checks off)" || no "bad none: $(grep -m1 error $O/bad-n.err)"
# the flag auto is no override: the default stops, an explicit draft stays
$T compile $C ../examples/skeleton.typ $O/bad-a.pdf --input invoice-pro-data-file=../data/bad.json --input invoice-pro-validation=auto >/dev/null 2>$O/bad-a.err; e=$?
[ $e = 1 ] && grep -q "$HINT" $O/bad-a.err && ok "bad.json with the flag auto: the default stop with the hint" || no "bad auto exit=$e: $(grep -m1 error $O/bad-a.err)"
$T compile $C explicit-draft.typ $O/explicit-auto.pdf --input invoice-pro-data-file=../data/broken-no-invoice-nr.json --input invoice-pro-validation=auto 2>/dev/null && pdftotext $O/explicit-auto.pdf - | grep -q ENTWURF && ok "the flag auto keeps an explicit validation: \"draft\"" || no "explicit draft with the flag auto"
# the findings of the layout join the stop: every one with the data's
# problems, as many as the draft counts, and the hint
for d in 2026-0042 bad; do
  $T compile $C layout.typ $O/layout-$d.pdf --input invoice-pro-data-file=../data/$d.json >/dev/null 2>$O/layout-$d.err; e=$?
  $T compile $C layout.typ $O/layout-$d-draft.pdf --input invoice-pro-data-file=../data/$d.json $DRAFT 2>/dev/null
  n=$(pdftotext $O/layout-$d-draft.pdf - | grep -m1 -o "ENTWURF · [0-9]* Probleme" | grep -o "[0-9]*")
  kinds=$(grep -o -e "areas::footer is" -e "does not appear in the first-page content" -e "has contrast" -e "parts::totals returned no content" $O/layout-$d.err | wc -l)
  [ $e = 1 ] && [ -n "$n" ] && grep -q "found $n problems in the hydrated invoice" $O/layout-$d.err && [ "$kinds" -ge 6 ] && grep -q "$HINT" $O/layout-$d.err && ok "layout findings, $d.json: the stop lists $n problems (footer fit, identity, scope contrast, empty totals; the draft counts $n) and ends with the hint" || no "layout $d exit=$e n=$n kinds=$kinds"
done
# an explicit level in the skeleton keeps its meaning when hydrated
$T compile $C explicit-draft.typ $O/explicit-draft.pdf --input invoice-pro-data-file=../data/broken-no-invoice-nr.json 2>/dev/null && pdftotext $O/explicit-draft.pdf - | grep -q ENTWURF && ok "validation: \"draft\" in the skeleton: hydrated, a draft (a deliberate debug choice)" || no "explicit draft"
# without data the default stays the 0.6.0 draft
$T compile $C explicit-draft.typ $O/nodata.pdf --input level=auto 2>/dev/null && pdftotext $O/nodata.pdf - | grep -q ENTWURF && ok "no data, validation: auto: a draft, as in 0.6.0" || no "no data auto"
panic() { # name expected-substring compile-args...
  local n=$1 want=$2; shift 2
  $T compile $C "$@" $O/$n.pdf >/dev/null 2>$O/$n.err; local e=$?
  if [ $e = 1 ] && grep -q -- "$want" $O/$n.err; then ok "panic $n: $(grep -m1 '^error' $O/$n.err | cut -c1-170)"; else no "panic $n exit=$e: $(grep -m1 '^error' $O/$n.err | cut -c1-200)"; fi
}
J="$(cat ../data/2026-0042.json)"
panic file-without-read "data.load(read: p => read(p, encoding: none))" zero.typ --input invoice-pro-data-file=../data/2026-0042.json
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
panic flag-case "use auto, none, draft or strict. Did you mean auto?" ../examples/skeleton.typ --input invoice-pro-validation=Auto
panic format-major "invoice-pro/2" major2.typ
panic two-markers "at most one" two-markers.typ
panic two-markers-data "at most one" two-markers.typ --input invoice-pro-data="$J"
panic marker-in-group "direct child of \`line-items\`" marker-in-group.typ
# the name `data` (Q19): a binding made before `import *` is replaced by the
# namespace (as for every new root export, concept L5); one made after it wins,
# and invoice(data:) takes the raw dictionary
panic shadow-before "module \`data\` does not contain \`nr\`" shadow-before.typ
$T compile $C shadow-after.typ $O/shadow-after.pdf 2>/dev/null && pdftotext $O/shadow-after.pdf - | grep -q "Rechnung 2026-0042" && ! pdftotext $O/shadow-after.pdf - | grep -q ENTWURF && ok "#let data = json(..) after import *: wins, invoice(data: <dictionary>) hydrates (final)" || no "shadow after"
# zero-code inline hydration works: complete data (2026-0042 with the
# creditor ID that zero.typ lacks) is final; without it the default stops
JC=$(printf '%s' "$J" | python3 -c 'import json,sys; d=json.load(sys.stdin); d["payment"]["creditor-id"]="DE98ZZZ09999999999"; print(json.dumps(d, ensure_ascii=False))')
$T compile $C zero.typ $O/zero-inline.pdf --input invoice-pro-data="$JC" 2>/dev/null && pdftotext $O/zero-inline.pdf - | grep -q "Rechnung 2026-0042" && ! pdftotext $O/zero-inline.pdf - | grep -q ENTWURF && ok "zero-code skeleton hydrates from inline JSON (final)" || no "zero inline"
$T compile $C zero.typ $O/zero-nocid.pdf --input invoice-pro-data="$J" >/dev/null 2>$O/zero-nocid.err; [ $? = 1 ] && grep -q "creditor-id" $O/zero-nocid.err && ok "zero-code skeleton, data without the creditor ID it relies on: the default stops (payment.creditor-id)" || no "zero without creditor ID"
# coverage: items without line-items, payment without payment(..)
$T compile $C no-binding.typ $O/no-binding.pdf --input invoice-pro-data-file=../data/2026-0042.json --input invoice-pro-validation=strict >/dev/null 2>$O/nb.err
grep -q "no \`line-items\`" $O/nb.err && grep -q "no \`payment(..)\` block" $O/nb.err && ok "coverage issues: schema/items and schema/payment" || no "coverage"
# blank required values (round 1): spaces as invoice-nr, a recipient named by empty lines
printf '%s' "$J" | python3 -c 'import json,sys; d=json.load(sys.stdin); d["invoice-nr"]="   "; d["recipient"]["name"]=["",""]; print(json.dumps(d))' > $O/blank.json
$T compile $C ../examples/skeleton.typ $O/blank-s.pdf --input invoice-pro-data="$(cat $O/blank.json)" --input invoice-pro-validation=strict >/dev/null 2>$O/blank-s.err
[ $? = 1 ] && grep -q "invoice-nr is missing" $O/blank-s.err && grep -q "recipient" $O/blank-s.err && ok "blank invoice-nr and recipient name: strict exit 1 with the problem list" || no "blank required"
echo "failures: $fails"
