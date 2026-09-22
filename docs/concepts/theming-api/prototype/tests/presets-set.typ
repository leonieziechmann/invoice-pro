// The shipped preset set (maintainer decision): exactly these ten presets, in the
// `theme` namespace and in the looks registry; `modern` is gone, `minimal` stays a
// docs recipe (tests/looks.typ). Every preset resolves, and all ten are distinct looks.
#import "/src/lib.typ": *
#import "/src/theming/presets.typ": looks
#let shipped = (
  "classic",
  "plain",
  "corporate",
  "elegant",
  "prestige",
  "bold",
  "technical",
  "soft",
  "compact",
  "boxed",
)
#let exported = (
  dictionary(theme)
    .keys()
    .filter(k => (
      k
        not in (
          "layout",
          "custom",
          "resolve",
          "unread-options",
          "parts",
          "contrast",
          "on-color",
          "legible",
        )
    ))
)
#assert.eq(
  exported.sorted(),
  shipped.sorted(),
  message: "theme exports " + repr(exported),
)
#assert.eq(looks.keys().sorted(), shipped.filter(k => k != "plain").sorted())
#assert(
  "modern" not in dictionary(theme) and "minimal" not in dictionary(theme),
)
#let env = (kind: "invoice", lang: "de", region: "de", e-invoice: none)
#let resolved = (
  shipped
    .map(n => (n, theme.resolve(dictionary(theme).at(n), env: env)))
    .to-dict()
)
// all looks except plain (classic's look on the plain layout) differ in tokens or options
#let sig(r) = repr((r.tokens, r.options))
#let looks-only = shipped.filter(n => n != "plain")
#for (i, a) in looks-only.enumerate() {
  for b in looks-only.slice(i + 1) {
    assert(
      sig(resolved.at(a)) != sig(resolved.at(b)),
      message: a + " and " + b + " resolve to the same tokens and options",
    )
  }
}
