#!/bin/bash
# Runs every proof P1..P10 on typst 0.15.1 and 0.14.2, sequentially (P9 first,
# on a quiet machine). Logs: proto/out/selfcheck/*.log
# The work layout of run.sh: <work>/{repo,pristine,proto}; this file in proto/.
P=$(cd "$(dirname "$0")" && pwd); U=$(cd "$P/.." && pwd); R=$U/repo
T=${TYPST_BIN:-typst}; T14=${TYPST14_BIN:-typst-0.14.2}; TYPSTYLE=${TYPSTYLE_BIN:-typstyle}; L=$P/out/selfcheck${SUFFIX}; mkdir -p $L
step() { echo "== $(date +%H:%M:%S) $1" | tee -a $L/progress.log; }
[ "$SKIP_WALL" = 1 ] || { step P9; (cd $P/bench; python3 -I p9.py $T 5; python3 -I p9.py $T14 5) > $L/p9.log 2>&1
step P9-s7a; (cd $P/bench; python3 -I p9-s7a.py $T 5; python3 -I p9-s7a.py $T14 5) > $L/p9-s7a.log 2>&1; }
step P9-import; (cd $P/bench; python3 -I imptrace.py $T 31; python3 -I imptrace.py $T14 31) > $L/p9-import.log 2>&1
step P1; (python3 -I $P/gen/gen.py 5,50,300 b,r,t; $P/eq/eq.sh $T "b r t" "5 50 300" "none auto"; $P/eq/eq.sh $T14 "b r t" "5 50 300" "none auto"; $P/edge/eq-edge.sh $T; $P/edge/eq-edge.sh $T14
  cd $P/examples; for X in $T $T14; do C="--root $U --creation-timestamp 1767225600 --pdf-standard a-3b"
    $X compile $C --input lib=pristine handwritten.typ $L/hw.pdf; $X compile $C skeleton.typ $L/sk.pdf --input invoice-pro-data-file=../data/2026-0042.json
    $X compile $C skeleton.typ $L/si.pdf --input invoice-pro-data="$(cat ../data/2026-0042.json)"
    echo "§3.10 $($X --version | cut -d' ' -f2) hand(pristine)=$(md5sum < $L/hw.pdf | cut -c1-12) file=$(md5sum < $L/sk.pdf | cut -c1-12) inline=$(md5sum < $L/si.pdf | cut -c1-12)"; done) > $L/p1.log 2>&1
step P2; ($P/regress/integration.sh $T; $P/regress/integration.sh $T14
  for X in $T $T14; do for t in pristine repo; do
    sed 's#@preview/invoice-pro:0.6.0#/src/lib.typ#' $U/$t/template/invoice.typ > $U/$t/template/_tpl.typ
    $X compile --root $U/$t --creation-timestamp 1767225600 $U/$t/template/_tpl.typ $L/tpl-$t.pdf 2>/dev/null
    echo "template $($X --version | cut -d' ' -f2) $t md5=$(md5sum < $L/tpl-$t.pdf | cut -c1-12) metadata=$($X query --root $U/$t $U/$t/template/_tpl.typ metadata 2>/dev/null | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
    rm $U/$t/template/_tpl.typ; done; done
  $P/regress/pages.sh $T pristine repo | tail -3; $P/regress/pages.sh $T14 pristine repo | tail -3) > $L/p2.log 2>&1
step P3; ($P/misuse/p3.sh $T; $P/misuse/p3.sh $T14) > $L/p3.log 2>&1
step P4; (cd $P/fuzz; python3 -I fuzz.py $T none; python3 -I fuzz.py $T14 none; python3 -I fuzz.py $T auto) > $L/p4.log 2>&1
step P5; (cd $R; $T eval --root $R '{ import "/src/lib.typ": invoice-data; invoice-data.schema() }' --pretty | diff -q - src/contract/invoice.schema.json && echo "schema drift: none (0.15)"
  printf '#import "/src/lib.typ": invoice-data\n#metadata(invoice-data.schema()) <s>\n' | $T14 query --root $R - '<s>' --field value --one | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin)==json.load(open(sys.argv[1])) else 1)' src/contract/invoice.schema.json && echo "schema drift: none (0.14)"
  $P/schema/codegen.sh
  python3 -I $P/schema/make_fixtures.py $P/data/2026-0042.json $R/src/contract/invoice.schema.json $R/tests/data/conformance/fixtures.json
  cd $R/tests/data/conformance; $T eval --root $R 'query(<r>).first().value' --in check-all.typ > $L/c15.json; $T14 query --root $R check-all.typ '<r>' --field value --one > $L/c14.json
  cmp $L/c15.json $L/c14.json && echo "check reports byte-identical on 0.15/0.14"; python3 -I $P/schema/compare.py $R/src/contract/invoice.schema.json fixtures.json $L/c15.json | tail -1
  cd $P/schema; $T eval --root $U 'query(<r>).first().value' --in check-d.typ > $L/d15.json; $T14 query --root $U check-d.typ '<r>' --field value --one > $L/d14.json
  cmp $L/d15.json $L/d14.json && echo "D-fixture reports byte-identical on 0.15/0.14"; python3 -I agree.py $R/src/contract/invoice.schema.json d-fixtures.json $L/d15.json | tail -1) > $L/p5.log 2>&1
step P6; ($P/payment/p6.sh $T; $P/payment/p6.sh $T14) > $L/p6.log 2>&1
step P7; ($P/wappen/p7.sh $T; $P/wappen/p7.sh $T14) > $L/p7.log 2>&1
step P8; $P/result/p8.sh $T $T14 > $L/p8.log 2>&1
step P10; $P/signature/p10.sh $T > $L/p10.log 2>&1
step unit; (for X in $T $T14; do $X compile --root $R $R/tests/data/contract/test.typ $L/t.pdf && echo "contract unit test ok ($($X --version | cut -d' ' -f2))"; $X compile --root $R $R/tests/theme/exports/test.typ $L/e.pdf && echo "exports test ok ($($X --version | cut -d' ' -f2))"; done
  cd $R; git diff --name-only df934a7 -- '*.typ' | xargs $TYPSTYLE --check && echo "typstyle 0.15.1: all changed/new .typ files of the repo clean"
  python3 -m unittest discover -s tools/perf -p 'test_gate.py' 2>&1 | tail -1) > $L/unit.log 2>&1
step done
