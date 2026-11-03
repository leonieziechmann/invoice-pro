#!/bin/bash
# P7: the §4.7 skeleton alone and hydrated without edits from inline JSON, a
# file, stdin, TOML and (0.15) a path; inline == file md5; the post code picks
# the arms, custom.wappen overrides; prints-of(theme).page-content false.
T=$1; cd "$(dirname "$0")/../examples"; U=$(cd ../.. && pwd); O=../out/p7-$(basename $T); mkdir -p $O; fails=0
V=$($T --version | cut -d' ' -f2); C="--root $U --creation-timestamp 1767225600 --pdf-standard a-3b"
ok() { echo "PASS $V $*"; }; no() { echo "FAIL $V $*"; fails=$((fails+1)); }
arms() { $T query --root $U skeleton.typ image --field source "$@" 2>/dev/null | python3 -c 'import json,sys; print(",".join(x for x in json.load(sys.stdin) if x.startswith("wappen")))'; }
md5() { md5sum < $1 | cut -c1-12; }
$T compile $C skeleton.typ $O/alone.pdf 2>$O/e && ok "alone: compiles, arms=$(arms), $(pdftotext $O/alone.pdf - | grep -m1 -o 'Rechnung MUSTER-0001'), XML $(pdfdetach -list $O/alone.pdf | tail -1 | awk '{print $2}')" || no "alone $(grep -m1 error $O/e)"
J=../data/2026-0042.json
$T compile $C skeleton.typ $O/file.pdf --input invoice-pro-data-file=$J 2>/dev/null
$T compile $C skeleton.typ $O/inline.pdf --input invoice-pro-data="$(cat $J)" 2>/dev/null
$T compile $C skeleton.typ $O/stdin.pdf --input invoice-pro-data-file=/dev/stdin < $J 2>$O/e1 || no "stdin: $(grep -m1 error $O/e1)"
$T compile $C skeleton.typ $O/toml.pdf --input invoice-pro-data-file=../data/2026-0042.toml 2>$O/e2 || no "toml: $(grep -m1 error $O/e2)"
f=$(md5 $O/file.pdf); i=$(md5 $O/inline.pdf); s=$(md5 $O/stdin.pdf); t=$(md5 $O/toml.pdf)
[ "$f" = "$i" ] && ok "inline == file: $f (arms=$(arms --input invoice-pro-data-file=$J))" || no "inline=$i file=$f"
[ "$s" = "$f" ] && ok "stdin (/dev/stdin) == file" || no "stdin=$s file=$f"
[ "$t" = "$f" ] && ok "TOML == JSON file" || no "toml=$t file=$f"
if [ "$V" != "0.14.2" ]; then
  $T compile $C skeleton-path.typ $O/path.pdf 2>$O/e3 && [ "$(md5 $O/path.pdf)" = "$f" ] && ok "0.15 path value == file" || no "path: $(md5 $O/path.pdf 2>/dev/null) $(grep -m1 error $O/e3)"
fi
declare -A WANT=([80331]=bayern [20095]=hamburg [10115]=berlin [50667]=neutral [override]=muenchen [unknown-name]=hamburg [city-string]=bayern)
for k in 80331 20095 10115 50667 override unknown-name city-string; do
  a=$(arms --input invoice-pro-data-file=../wappen/w-$k.json)
  [ "$a" = "wappen/${WANT[$k]}.svg" ] && ok "arms for $k: $a" || no "arms for $k: $a (want ${WANT[$k]})"
done
r=$($T query --root $U ../wappen/prints-probe.typ '<r>' --field value --one --input invoice-pro-data-file=$J 2>/dev/null)
echo "$r" | python3 -c 'import json,sys; r=json.load(sys.stdin); sys.exit(0 if r["skeleton-patch"] is False and r["classic"] is False and r["draw-time-wrap"] is True else 1)' && ok "prints-of page-content: $r" || no "prints-of: $r"
echo "failures: $fails"
