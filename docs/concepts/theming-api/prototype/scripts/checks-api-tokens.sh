#!/bin/sh
# api-tokens checks: new frozen tokens, checks.pairs, theme label strings, per-part
# option metadata. Sourced by scripts/run-all.sh (uses its c/ok/bad helpers and $fail).
c "api-tokens: tokens, pairs, label strings, option metadata" tests/api-tokens.typ out/api-tokens.pdf
# page-number.format is ctx-first; default label from strings.document.page; embedded fonts only
for lang in de en fr it es; do
  c "api-tokens: page label + ctx-first format ($lang, embedded fonts)" --ignore-system-fonts --input fmt=ctx --input lang=$lang tests/api-tokens-render.typ "out/at-ctx-$lang-{p}.png" --ppi 60
done
c "api-tokens: default page label (fr, embedded fonts)" --ignore-system-fonts --input lang=fr tests/api-tokens-render.typ "out/at-fr-{p}.png" --ppi 60
# misuse and strict probes (expected message fragments)
cat > out/api-tokens-fail.typ <<'TYP'
#import "/src/lib.typ": *
#let c = sys.inputs.at("c")
#let p = (
  one-colour: () => theme.custom.checks(pairs: (bad: t => t.colors.primary)),
  literal: () => theme.custom.checks(pairs: (lit: (red, blue, green))),
  array: () => ((checks: (pairs: (t => (red, blue),))),),
  helper-array: () => theme.custom.checks(pairs: (t => (red, blue),)),
  strict-low: () => theme.custom.checks(min-contrast: 4.5, pairs: (disc: t => (t.colors.tint, t.colors.background))),
).at(c)()
#let v = if c == "strict-low" { "strict" } else { none }
#let _ = theme.resolve(theme.classic.with(p), validation: v)
TYP
for pair in "one-colour:theme::checks::pairs::bad must be a derivation \`t => (foreground, background)\` or a pair of colours, found rgb(\"#1f2937\") (returned by the derivation)" \
  "literal:theme::checks::pairs::lit must be a derivation \`t => (foreground, background)\` or a pair of colours, found (" \
  "array:variable \`theme::checks::pairs\`(" \
  "helper-array:variable \`theme::custom::checks::pairs\`(" \
  "strict-low:theme: checks::pairs::disc (#e2e8f0 on #ffffff) has contrast 1.23:1, below checks.min-contrast 4.5:1"; do
  k=${pair%%:*}; want=${pair#*:}
  msg=$(typst compile --root . --input c=$k out/api-tokens-fail.typ out/api-tokens-fail.pdf 2>&1 | awk -f scripts/panic-text.awk)
  case "$msg" in *"$want"*) ok "api-tokens: $k rejected with the pair named";; *) bad "api-tokens: $k rejected with the pair named"; echo "  got: $msg";; esac
done
