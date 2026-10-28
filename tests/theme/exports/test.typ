// API hygiene (prototype tests/polish/exports.typ): the exported names of every
// public module == the documented lists (concept §2.1, §2.4, §3.6, §8.1). A Typst
// module exports every top-level name, imports included, so an internal helper
// imported into a public module becomes API by accident.
#import "/src/lib.typ" as lib
#import "/src/lib.typ": *

#let names(m) = dictionary(m).keys().sorted()
#let expect(label, m, documented) = {
  let got = names(m)
  let want = documented.sorted()
  let extra = got.filter(n => n not in want)
  let missing = want.filter(n => n not in got)
  assert(
    extra == () and missing == (),
    message: label
      + ": undocumented export(s) "
      + repr(extra)
      + ", missing export(s) "
      + repr(missing),
  )
}

// the package root: the 0.5 names (payment-goal renamed, themes removed) plus
// theme, themed, the payment means (card-payment, direct-debit, paid) and the
// identifiers (id)
#expect("invoice-pro", lib, (
  "apply",
  "bank-details",
  "bundle",
  "card-payment",
  "country",
  "date",
  "direct-debit",
  "discount",
  "dynamic",
  "group",
  "id",
  "info",
  "invoice",
  "item",
  "line-items",
  "locale",
  "modifier",
  "paid",
  "payment-terms",
  "prepayment",
  "references",
  "signature",
  "surcharge",
  "tax",
  "theme",
  "themed",
  "unit",
))
// §2.1: presets, layout, custom, resolve, parts, colour helpers
#let presets = (
  "bold",
  "boxed",
  "classic",
  "compact",
  "corporate",
  "elegant",
  "plain",
  "prestige",
  "soft",
  "technical",
)
#expect(
  "theme",
  theme,
  presets
    + (
      "contrast",
      "custom",
      "layout",
      "legible",
      "on-color",
      "parts",
      "resolve",
    ),
)
// §8.1: 16 layouts, derive, the envelope catalogue, folded, 7 region functions
#let layouts = (
  "a4-band",
  "a4-dense",
  "a4-digital",
  "a4-sidebar",
  "a4-window-left",
  "a4-window-right",
  "din-5008-a",
  "din-5008-b",
  "plain",
  "sn-010130-left",
  "sn-010130-right",
  "us-letter-10",
  "us-letter-band",
  "us-letter-dense",
  "us-letter-digital",
  "us-letter-sidebar",
)
#assert(layouts.len() == 16)
#expect(
  "theme.layout",
  theme.layout,
  layouts
    + (
      "derive",
      "envelope",
      "folded",
      "for-region",
      "paper-for-region",
      "digital-for-region",
      "plain-for-region",
      "sidebar-for-region",
      "band-for-region",
      "dense-for-region",
      "reserve-qr-bill",
    ),
)
// §2.4: one helper per group, layout/part/check/macro helpers, markers, from-data
#expect("theme.custom", theme.custom, (
  "colors",
  "fonts",
  "sizes",
  "weights",
  "strokes",
  "spacing",
  "radii",
  "page",
  "stationery",
  "marks",
  "envelopes",
  "proof",
  "area",
  "part",
  "wrap",
  "brand",
  "reset",
  "replace",
  "checks",
  "logo",
  "title",
  "line-items",
  "items-table",
  "totals",
  "bank-details",
  "page-number",
  "continuation",
  "row",
  "from-data",
))
// §3.6: the 23 frozen part names of the concept, and the parts of the payment
// means and of the e-invoice report; nothing else (no kit helpers, no imports)
#let part-names = (
  "title",
  "recipient",
  "sender",
  "company",
  "return-address",
  "registration",
  "references",
  "reference-list",
  "logo",
  "sender-details",
  "contact",
  "bank-account",
  "page-number",
  "continuation",
  "marks",
  "qr-bill",
  "line-items",
  "items-table",
  "totals",
  "notes",
  "bank-details",
  "payment-terms",
  "payment-means",
  "signature",
  "zugferd-report",
)
#assert(part-names.len() == 25)
#expect("theme.parts", theme.parts, part-names)
// validation (§7): the API is `invoice(validation:)`, `theme.resolve(validation:)`
// and `--input invoice-pro-validation`; no validation module or helper is exported
#for n in (
  "validation",
  "resolve-level",
  "check-data",
  "issue",
  "render-report",
) {
  assert(n not in names(lib), message: "invoice-pro exports " + n)
}
// no public module exports a `_`-prefixed name or a patch/validation internal
#let internal = ("emit", "clean-auto", "merge", "resolve-level", "check-data")
#for (label, m) in (
  ("invoice-pro", lib),
  ("theme", theme),
  ("theme.layout", theme.layout),
  ("theme.custom", theme.custom),
  ("theme.parts", theme.parts),
  ("locale", locale),
  ("tax", tax),
  ("unit", unit),
  ("country", country),
  ("references", references),
  ("info", info),
) {
  for n in names(m) {
    assert(
      not n.starts-with("_") and n not in internal,
      message: label + " exports the internal name " + n,
    )
  }
}
