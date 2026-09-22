#!/bin/sh
# compat-014: PDF-standard exports on whatever `typst` is on PATH.
# ua-1 per look (image logo with alt), a-3b + ZUGFeRD per look, and the combined a-3a,ua-1
# (expected: rejected on 0.14.x, accepted on 0.15+).
set -u
fail=0
O=${OUT:-out/pdf}
v=$(typst --version | cut -d' ' -f2)
mkdir -p $O
for look in classic corporate plain minimal; do
  if typst compile --root . --pdf-standard ua-1 --input look=$look tests/compat/ua.typ $O/ua1-$look.pdf >$O/log 2>&1; then echo "ok   ua-1 $look"; else echo "FAIL ua-1 $look"; sed -n 1,8p $O/log; fail=1; fi
  if typst compile --root . --pdf-standard a-3b --input look=$look --input zugferd=basic tests/compat/ua.typ $O/a3b-$look.pdf >$O/log 2>&1; then echo "ok   a-3b+zugferd $look"; else echo "FAIL a-3b+zugferd $look"; sed -n 1,8p $O/log; fail=1; fi
  if typst compile --root . --pdf-standard a-3b --input look=$look --input zugferd=en16931 tests/compat/ua.typ $O/a3b-en-$look.pdf >$O/log 2>&1; then echo "ok   a-3b+zugferd(en16931) $look"; else echo "FAIL a-3b+zugferd(en16931) $look"; sed -n 1,8p $O/log; fail=1; fi
done
if typst compile --root . --pdf-standard a-3a,ua-1 --input zugferd=basic tests/compat/ua.typ $O/a3a-ua1.pdf >$O/log 2>&1; then
  case $v in 0.14.*) echo "FAIL a-3a,ua-1 accepted on $v (concept says rejected)"; fail=1;; *) echo "ok   a-3a,ua-1 accepted on $v";; esac
else
  case $v in 0.14.*) echo "ok   a-3a,ua-1 rejected on $v: $(grep -m1 '^error' $O/log)";; *) echo "FAIL a-3a,ua-1 rejected on $v"; sed -n 1,8p $O/log; fail=1;; esac
fi
exit $fail
