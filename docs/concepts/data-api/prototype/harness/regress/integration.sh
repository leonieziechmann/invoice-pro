#!/bin/bash
# P2: every tests/integration/**/test.typ (66: 60 top-level + 6 nested)
# compiled to PDF against pristine and the prototype (each with its own
# --root); byte comparison of the PDFs.
# usage: integration.sh TYPST
T=$1; U=$(cd "$(dirname "$0")/../.." && pwd); OUT=$U/proto/out/integration-$(basename $T); rm -rf $OUT; mkdir -p $OUT
ok=0; diff=0; both=0; list=""
for f in $(cd $U/pristine/tests/integration && find . -name test.typ | sort); do
  rel=${f#./}; n=$(dirname $rel | tr / _)
  C="--creation-timestamp 1767225600 --pdf-standard a-3b"
  $T compile --root $U/pristine $C $U/pristine/tests/integration/$rel $OUT/$n-p.pdf >/dev/null 2>$OUT/$n-p.err; a=$?
  $T compile --root $U/repo $C $U/repo/tests/integration/$rel $OUT/$n-r.pdf >/dev/null 2>$OUT/$n-r.err; b=$?
  if [ $a = 0 ] && [ $b = 0 ]; then
    if cmp -s $OUT/$n-p.pdf $OUT/$n-r.pdf; then ok=$((ok+1)); else diff=$((diff+1)); list="$list $n"; fi
  elif [ $a = $b ] && [ "$(grep -m1 '^error' $OUT/$n-p.err)" = "$(grep -m1 '^error' $OUT/$n-r.err)" ]; then both=$((both+1))
  else diff=$((diff+1)); list="$list $n(exit:$a/$b)"; fi
done
echo "$($T --version | cut -d' ' -f2) integration: $((ok+diff+both)) tests, identical PDFs=$ok, same error=$both, differ=$diff$list"
