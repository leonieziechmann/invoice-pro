#!/bin/bash
# compat-014: wall-clock timings (ms) of full PDF compiles with the typst on PATH.
# RUNS (default 5) runs each; prints all runs and the median. Fonts are pinned
# (--ignore-system-fonts --font-path parity/fonts) so that system font scanning
# (thousands of Nerd/Noto fonts in WSL) does not dominate. Run from the prototype root;
# baseline-042/ holds bench-n.typ for the unmodified 0.4.2 src; populate its src/ with
#   git -C <invoice-pro repo> archive v0.4.2 src | tar -x -C baseline-042
# (skipped when baseline-042/src is missing).
RUNS=${RUNS:-5}
F="--ignore-system-fonts --font-path parity/fonts"
[ "${FONTS:-fixed}" = system ] && F=""
echo '#set page(width: 5cm, height: 2cm)
hello' > /tmp/trivial.typ
t() { label=$1; shift; all=(); for r in $(seq $RUNS); do s=$(date +%s%N); typst compile $F "$@" /tmp/bench.pdf >/dev/null 2>&1 || { echo "$label FAILED"; return; }; e=$(date +%s%N); all+=($(( (e - s) / 1000000 ))); done
  med=$(printf '%s\n' "${all[@]}" | sort -n | sed -n "$(( (RUNS + 1) / 2 ))p"); pages=$(grep -a -c "/Type /Page$" /tmp/bench.pdf); echo "$label | ${all[*]} | median $med | pages $pages"; }
typst --version
t "trivial doc (startup)"       /tmp/trivial.typ
t "proto bench-150 sealed"      --root . tests/bench-150.typ
t "proto bench-150 ip-seal=0"   --root . --input ip-seal=0 tests/bench-150.typ
for n in 1 150 400; do
  [ -d baseline-042/src ] && t "0.4.2 n=$n"                --root baseline-042 --input n=$n baseline-042/bench-n.typ
  t "proto n=$n sealed"         --root . --input n=$n tests/compat/bench-n.typ
  t "proto n=$n ip-seal=0"      --root . --input n=$n --input ip-seal=0 tests/compat/bench-n.typ
done
