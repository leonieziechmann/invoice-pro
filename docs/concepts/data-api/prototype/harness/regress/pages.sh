#!/bin/bash
# (design C's regress.sh) Compile every tests/**/test.typ of the repo against
# several trees and compare the rendered pages (PNG md5) and the error text.
# usage: pages.sh TYPST pristine repo   (each tree has src/ and tests/)
T=$1; shift
D=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$D/proto/out/pages-$(basename $T); rm -rf $OUT; mkdir -p $OUT
cd $D/pristine
find tests -name test.typ | sort > $OUT/list.txt
run() { # root test
  r=$1; t=$2; id=$(echo "$t" | tr '/' '_')
  o=$OUT/$(basename $r)/$id; mkdir -p $o
  if $T compile --root $D/$r --ppi 30 --creation-timestamp 1767225600 $D/$r/$t "$o/p{0p}.png" > $o/err.txt 2>&1; then
    md5sum $o/*.png | awk '{print $1}' | md5sum | cut -c1-12 > $o/sum
  else
    grep -m1 -E "error|panicked" $o/err.txt | md5sum | cut -c1-12 | sed 's/^/ERR-/' > $o/sum
  fi
  rm -f $o/*.png
}
export -f run; export T D OUT
for r in "$@"; do cat $OUT/list.txt | xargs -P3 -I{} bash -c "run $r {}"; done
same=0; diff=0
while read t; do
  id=$(echo "$t" | tr '/' '_'); ref=$(cat $OUT/$1/$id/sum)
  ok=1; for r in "$@"; do [ "$(cat $OUT/$r/$id/sum)" = "$ref" ] || ok=0; done
  if [ $ok = 1 ]; then same=$((same+1)); else diff=$((diff+1)); echo "DIFF $t: $(for r in "$@"; do echo -n "$r=$(cat $OUT/$r/$id/sum) "; done)"; fi
done < $OUT/list.txt
echo "tests: $((same+diff)) identical: $same different: $diff (errors counted by message)"
grep -l "" $OUT/$1/*/sum | xargs cat | grep -c ERR- | sed 's/^/expected-error tests in first root: /'
