#!/bin/bash
# P6: payment matrix. Without data: payment(..) == the components by hand
# (md5, vs pristine 0.6.0 too). With data: the §4.7 skeleton hydrated with
# 2026-0042 + a payment section == handwritten.typ --input pay=<mode> (md5),
# BT-81 code and account in the XML (the rules engine checks CII-SR-467/470;
# zugferd-errors "panic" would stop on them); incomplete data -> data issue.
T=$1; cd "$(dirname "$0")"; U=$(cd ../.. && pwd); O=../out/p6-$(basename $T); mkdir -p $O; fails=0
V=$($T --version | cut -d' ' -f2); C="--root $U --creation-timestamp 1767225600 --pdf-standard a-3b"
ok() { echo "PASS $V $*"; }; no() { echo "FAIL $V $*"; fails=$((fails+1)); }
xmlinfo() { # pdf -> "code=<BT-81> account=<yes|no> terms=<yes|no>"
  rm -rf $O/x; mkdir -p $O/x; pdfdetach -saveall -o $O/x $1 >/dev/null 2>&1
  local f=$(ls $O/x/*.xml 2>/dev/null | head -1); [ -z "$f" ] && { echo "no-xml"; return; }
  local code=$(grep -o "<ram:TypeCode>[0-9]*</ram:TypeCode>" $f | sed 's/<[^>]*>//g' | tail -1)
  local acc=$(grep -q "PayeePartyCreditorFinancialAccount" $f && echo yes || echo no)
  local terms=$(grep -q "<ram:DueDateDateTime>" $f && echo yes || echo no)  # the terms (due date) of the skeleton/data
  echo "code=$code account=$acc due-terms=$terms"
}
declare -A WANT=([transfer]="code=58 account=yes due-terms=yes" [direct-debit]="code=59 account=no due-terms=yes" [card]="code=54 account=no due-terms=yes" [paid-cash]="code=10 account=no due-terms=no" [paid-transfer]="code=58 account=yes due-terms=no")
for m in transfer direct-debit card paid-cash paid-transfer; do
  # without data
  $T compile $C --input pay=$m pay-skel.typ $O/nd-skel-$m.pdf 2>$O/e1 || { no "no-data $m skel: $(grep -m1 error $O/e1)"; continue; }
  $T compile $C --input pay=$m --input lib=pristine pay-hand.typ $O/nd-p-$m.pdf 2>$O/e2 || no "no-data $m pristine: $(grep -m1 error $O/e2)"
  $T compile $C --input pay=$m pay-hand.typ $O/nd-h-$m.pdf 2>$O/e3 || no "no-data $m hand"
  a=$(md5sum < $O/nd-skel-$m.pdf | cut -c1-12); b=$(md5sum < $O/nd-p-$m.pdf | cut -c1-12); c=$(md5sum < $O/nd-h-$m.pdf | cut -c1-12)
  [ "$a" = "$b" ] && [ "$b" = "$c" ] && ok "no data   $m: payment(..) == components (pristine and prototype) $a, XML $(xmlinfo $O/nd-skel-$m.pdf)" || no "no data $m: skel=$a pristine=$b hand=$c"
  # with data
  $T compile $C ../examples/skeleton.typ $O/d-$m.pdf --input invoice-pro-data-file=../payment/pay-$m.json 2>$O/e4 || { no "data $m: $(grep -m1 error $O/e4 | cut -c1-200)"; continue; }
  $T compile $C --input pay=$m --input lib=pristine ../examples/handwritten.typ $O/dh-$m.pdf 2>$O/e5 || no "data $m pristine hand: $(grep -m1 error $O/e5)"
  a=$(md5sum < $O/d-$m.pdf | cut -c1-12); b=$(md5sum < $O/dh-$m.pdf | cut -c1-12); x=$(xmlinfo $O/d-$m.pdf)
  [ "$a" = "$b" ] && [ "$x" = "${WANT[$m]}" ] && ok "with data $m: hydrated == hand (pristine) $a, XML $x" || no "with data $m: hydrated=$a hand=$b XML [$x] want [${WANT[$m]}]"
done
for m in missing-mandate missing-last4 paid-and-terms; do
  $T compile $C ../examples/skeleton.typ $O/d-$m.pdf --input invoice-pro-data-file=../payment/pay-$m.json 2>$O/e6
  t=$(pdftotext $O/d-$m.pdf - | grep -m1 -o "ENTWURF · [0-9]* Probl[a-z]*"); n=$(pdfdetach -list $O/d-$m.pdf | head -1)
  $T compile $C ../examples/skeleton.typ $O/s-$m.pdf --input invoice-pro-data-file=../payment/pay-$m.json --input invoice-pro-validation=strict >/dev/null 2>$O/e7
  msg=$(grep -o "invoice data[^\n]*" $O/e7 | head -1 | cut -c1-140)
  [ -n "$t" ] && [ "$n" = "0 embedded files" ] && [ -n "$msg" ] && ok "issue $m: draft [$t], XML withheld; strict: $msg" || no "issue $m: [$t] [$n] [$msg]"
done
# round 1: what the components stop on is a data issue when hydrated (draft,
# XML withheld, strict exit 1); the details of another method are an issue too
issue() { # name skeleton data-file expected-message-part
  $T compile $C $2 $O/r1-$1.pdf --input invoice-pro-data-file=../payment/$3 >/dev/null 2>$O/r1e1
  local t=$(pdftotext $O/r1-$1.pdf - 2>/dev/null | grep -m1 -o "ENTWURF · [0-9]* Probl[a-z]*"); local n=$(pdfdetach -list $O/r1-$1.pdf 2>/dev/null | head -1)
  $T compile $C $2 $O/r1s-$1.pdf --input invoice-pro-data-file=../payment/$3 --input invoice-pro-validation=strict >/dev/null 2>$O/r1e2; local e=$?
  [ -n "$t" ] && [ "$n" = "0 embedded files" ] && [ $e = 1 ] && grep -q -- "$4" $O/r1e2 && ok "issue $1: draft [$t], XML withheld; strict exit 1: $(grep -o "invoice data[^.]*" $O/r1e2 | head -1 | cut -c1-120)" || no "issue $1: [$t] [$n] strict=$e $(grep -m1 error $O/r1e1 $O/r1e2 | cut -c1-200)"
}
issue credit-skonto ../examples/skeleton.typ pay-credit-skonto.json "no cash discount"
issue credit-direct-debit ../examples/skeleton.typ pay-credit-direct-debit.json "cannot collect the amount"
issue method-mismatch ../examples/skeleton.typ pay-method-mismatch.json "or leave"
issue transfer-no-account ../examples/skeleton-no-bank.typ pay-transfer-no-account.json "no account to pay to"
issue sample-dd-replaced ../examples/skeleton-no-bank.typ pay-none.json "no account to pay to"
# round 2: paid by transfer (the data's `paid`) without any account is an issue too
issue paid-transfer-no-account ../examples/skeleton-no-bank.typ pay-paid-transfer-no-account.json "paid by transfer"
# round 2 (decision, deviation 41): a data `bank` with a card payment is left
# out like the skeleton's own account: clean, BT-81 54, no account, IBAN not printed
$T compile $C ../examples/skeleton.typ $O/r2-card-bank.pdf --input invoice-pro-data-file=../payment/pay-card-with-bank.json 2>$O/r2e1
x=$(xmlinfo $O/r2-card-bank.pdf); p=$(pdftotext $O/r2-card-bank.pdf - | tr -d ' ' | grep -c DE02120300000000202051)
[ "$x" = "code=54 account=no due-terms=yes" ] && [ "$p" = 0 ] && ok "card + data bank: clean, XML $x, data IBAN not printed (deviation 41)" || no "card + data bank: XML [$x] printed=$p $(grep -m1 error $O/r2e1)"
echo "failures: $fails"
