#!/bin/bash
# P10: tools/contract/signature.py passes on the prototype and FAILS when an
# invoice() parameter is not classified in the descriptor, a classified key is
# no parameter, a class or role is misspelt, or `data` is reclassified (each a
# mutated copy). Runs on 0.15 and 0.14 (signature.py falls back to query).
T=$1; D=$(cd "$(dirname "$0")" && pwd); R=$(cd $D/../../repo && pwd); W=$D/work; fails=0
python3 -I $R/tools/contract/signature.py --root $R --typst $T && echo "PASS prototype covered" || { echo "FAIL prototype"; fails=1; }
for m in unclassified stale role-typo class-typo data-class; do
  rm -rf $W; mkdir -p $W; cp -r $R/src $R/typst.toml $W/
  if [ $m = unclassified ]; then
    # a new parameter nobody classified (and that hydrate() does not get)
    python3 -I -c 'import sys; p=sys.argv[1]; s=open(p).read(); s=s.replace("  custom: none,\n", "  /// A new parameter.\n  /// -> none | str\n  watermark: none,\n  custom: none,\n", 1); open(p, "w").write(s)' $W/src/invoice.typ
  elif [ $m = stale ]; then
    # a classified key that is no parameter any more
    sed -i 's/^      quote-nr: field($/      quote-nr-old: field(/' $W/src/contract/schema.typ
  elif [ $m = role-typo ]; then
    # a misspelt role: a hydrated invoice would drop the key silently
    python3 -I -c 'import sys; p=sys.argv[1]; s=open(p).read(); i=s.index("      quote-nr: field("); j=s.index("role: \"document\"", i); open(p, "w").write(s[:j] + "role: \"documnet\"" + s[j+len("role: \"document\""):])' $W/src/contract/schema.typ
  elif [ $m = class-typo ]; then
    # a misspelt fixed class: a hydrated invoice would drop the theme
    sed -i 's/^    theme: "design",$/    theme: "desing",/' $W/src/contract/schema.typ
  else
    # the hydration source classified as design
    sed -i 's/^    data: "data",$/    data: "design",/' $W/src/contract/schema.typ
  fi
  python3 -I $R/tools/contract/signature.py --root $W --typst $T > $W/out.txt; e=$?
  [ $e = 1 ] && echo "PASS mutation '$m' fails: $(head -2 $W/out.txt | tr '\n' ' ' | cut -c1-260)" || { echo "FAIL mutation $m exit=$e"; cat $W/out.txt; fails=1; }
done
rm -rf $W; echo "failures: $fails"
