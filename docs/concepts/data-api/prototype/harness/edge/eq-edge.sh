#!/bin/bash
# P1 edge fixtures: md5 of hand-written (pristine 0.6.0 and prototype) vs the
# hydrated skeleton. usage: eq-edge.sh TYPST
T=$1; cd "$(dirname "$0")"; U=$(cd ../.. && pwd); mkdir -p out; fails=0
V=$($T --version | cut -d' ' -f2)
run() { # name zf "hand inputs" handfile "skel inputs" skelfile
  local n=$1 z=$2 hi=$3 hf=$4 si=$5 sf=$6
  local C="--root $U --input zf=$z --creation-timestamp 1767225600 --pdf-standard a-3b"
  $T compile $C --input lib=pristine $hi $hf out/P-$n-$z.pdf 2>out/err.txt || { echo "FAIL pristine $n"; tail -3 out/err.txt; }
  $T compile $C --input lib=repo $hi $hf out/H-$n-$z.pdf 2>out/err.txt || { echo "FAIL hand $n"; tail -3 out/err.txt; }
  $T compile $C $si $sf out/D-$n-$z.pdf 2>out/err.txt || { echo "FAIL data $n"; tail -6 out/err.txt; }
  local p=$(md5sum < out/P-$n-$z.pdf | cut -c1-12) h=$(md5sum < out/H-$n-$z.pdf | cut -c1-12) d=$(md5sum < out/D-$n-$z.pdf | cut -c1-12)
  local x=$(pdfdetach -list out/D-$n-$z.pdf 2>/dev/null | tail -n +2 | awk '{print $2}' | tr '\n' ' ')
  [ "$p" = "$h" ] && [ "$h" = "$d" ] && r=IDENTICAL || { r=DIFF; fails=$((fails+1)); }
  echo "$V $n-$z pristine=$p hand=$h data=$d $r attach=[$x]"
}
for z in none auto; do
  run nested-bundles $z "--input nul=0" edge-hand.typ "--input invoice-pro-data-file=edge.json" edge-skel.typ
  run nulls-as-absent $z "--input nul=0" edge-hand.typ "--input invoice-pro-data-file=edge-nulls.json" edge-skel.typ
  run flat-bundles $z "--input nul=0 --input flat=1" edge-hand.typ "--input invoice-pro-data-file=edge-flat.json" edge-skel.typ
  run apply-around-marker $z "--input nul=0 --input wrap=1" edge-hand.typ "--input wrap=1 --input invoice-pro-data-file=edge.json" edge-skel.typ
  run static-rows-marker $z "" marker-hand.typ "--input marker=1 --input invoice-pro-data-file=edge.json" edge-skel.typ
  run marker-preview $z "--input rows=sample" marker-hand.typ "--input marker=1" edge-skel.typ
done
run inclusive-smallbiz-at none "" e2-hand.typ "--input invoice-pro-data-file=e2.json" e2-skel.typ
echo "diff: $fails"
