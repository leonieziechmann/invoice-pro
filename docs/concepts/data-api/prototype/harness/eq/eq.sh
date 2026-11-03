#!/bin/bash
# P1 matrix: md5 (PDF incl. the embedded XML) of
#   P = hand-written on pristine 0.6.0, H = hand-written on the prototype,
#   D = the skeleton hydrated with the data (prototype)
# usage: eq.sh TYPST "kinds" "sizes" "zfs"
T=$1; cd "$(dirname "$0")"; U=$(cd ../.. && pwd); mkdir -p out
fails=0
for k in $2; do for n in $3; do for z in $4; do
  C="--root $U --input zf=$z --creation-timestamp 1767225600 --pdf-standard a-3b"
  $T compile $C --input lib=pristine hand/$k-$n.typ out/P-$k-$n-$z.pdf 2>out/err.txt || { echo FAIL pristine; tail -3 out/err.txt; }
  $T compile $C --input lib=repo hand/$k-$n.typ out/H-$k-$n-$z.pdf 2>out/err.txt || { echo FAIL hand; tail -3 out/err.txt; }
  $T compile $C --input invoice-pro-data-file=data/$k-$n.json skeleton.typ out/D-$k-$n-$z.pdf 2>out/err.txt || { echo FAIL data; tail -5 out/err.txt; }
  p=$(md5sum < out/P-$k-$n-$z.pdf | cut -c1-12); h=$(md5sum < out/H-$k-$n-$z.pdf | cut -c1-12); d=$(md5sum < out/D-$k-$n-$z.pdf | cut -c1-12)
  x=$(pdfdetach -list out/D-$k-$n-$z.pdf 2>/dev/null | tail -n +2 | awk '{print $2}' | tr '\n' ' ')
  [ "$p" = "$h" ] && [ "$h" = "$d" ] && r=IDENTICAL || { r=DIFF; fails=$((fails+1)); }
  echo "$($T --version | cut -d' ' -f2) $k-$n-$z pristine=$p hand=$h data=$d $r attach=[$x]"
done; done; done
echo "diff: $fails"
