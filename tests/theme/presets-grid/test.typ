/// [ppi: 12]

// The technical and soft presets (prototype tests/presets-grid.typ, gallery
// technical/soft, scripts/checks-presets-grid.sh): contrast (core pairs + the
// looks' checks.pairs) for the default seed and brand seeds from very dark to
// very light under strict, the looks' own pairs, the replaced-part budget, the
// kit; a 4-item invoice on one page on the default layout, the galleries under
// strict with checks(min-contrast: 4.5) and with ZUGFeRD (the XML is attached),
// multi-page invoices, and the totals travelling with the last row on US Letter
// (the draft renders: tests/validation/draft-technical, draft-soft).
#import "/src/lib.typ": *
#import "/src/theming/looks/kit.typ"

#let seeds = (
  auto,
  rgb("#0f766e"),
  rgb("#111827"),
  rgb("#facc15"),
  rgb("#db2777"),
  rgb("#a3e635"),
  rgb("#1d4ed8"),
  rgb("#9c3d26"),
)
#for (name, preset) in (technical: theme.technical, soft: theme.soft) {
  for seed in seeds {
    // strict: any pair below 4.5:1 panics and names the pair
    let th = theme.resolve(preset.with(
      theme.custom.colors(primary: seed),
      theme.custom.checks(min-contrast: 4.5),
    ))
    let pairs = th.checks.pairs
    assert(
      pairs.len() >= 2,
      message: name + ": declares its own contrast pairs",
    )
  }
}

// the looks' pairs are registered under their names
#let th = theme.resolve(theme.technical)
#assert(
  "technical-accent-labels" in th.checks.pairs
    and "technical-payable" in th.checks.pairs,
)
#let th = theme.resolve(theme.soft)
#assert(
  "soft-brand-on-tint" in th.checks.pairs
    and "soft-text-on-tint" in th.checks.pairs,
)

// replaced-part budget: the built-in items table stays (totals as its footer in
// technical; a wrap in soft), few replaced renderers
#let replaced(p) = theme.resolve(p).spec.replaced
#assert(
  "items-table" not in replaced(theme.technical),
  message: "technical keeps the built-in items table",
)
#assert(
  "items-table" not in replaced(theme.soft),
  message: "soft wraps (not replaces) the items table",
)
#assert(
  replaced(theme.technical).len() <= 4,
  message: "technical replaces " + repr(replaced(theme.technical)),
)
#assert(
  replaced(theme.soft).len() <= 6,
  message: "soft replaces " + repr(replaced(theme.soft)),
)

// kit.strip-word: the title stack never repeats the document word
#assert.eq(kit.strip-word("Invoice — Sprint 14", "Invoice"), "Sprint 14")
#assert.eq(kit.strip-word("invoice: March", "Invoice"), "March")
#assert.eq(kit.strip-word("Rechnung", "Rechnung"), none)
#assert.eq(
  kit.strip-word("Catering am 12.09.", "Rechnung"),
  "Catering am 12.09.",
)
#assert.eq(kit.strip-word([Invoice X], "Invoice"), [Invoice X]) // content stays as it is

#import "/tests/theme/body.typ": body, logo-img, party, preset-of
#import "/tests/theme/gallery/technical.typ": gallery as technical-gallery
#import "/tests/theme/gallery/soft.typ": gallery as soft-gallery
#import "/tests/theme/harness.typ": case, case-marker, close-cases, span-of
#import "/tests/test-locale.typ": test-locale

#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)
#for look in ("technical", "soft") {
  case(
    look + "/auto",
    theme: preset-of(look).with(brand),
    locale: test-locale,
    ..party,
    body(n: 4),
  )
}
#let galleries = (
  technical: technical-gallery,
  soft: soft-gallery,
)
#for (look, gallery) in galleries {
  gallery(
    checks: true,
    validation: "strict",
    marker: case-marker(look + "/checks"),
  )
  gallery(
    zugferd: "basic",
    validation: "strict",
    marker: case-marker(look + "/zugferd"),
  )
  gallery(
    extra: if look == "soft" { 40 } else { 28 },
    marker: case-marker(look + "/long"),
  )
}
// the totals travel with the last row (table footer): the widow case of the review
#technical-gallery(
  layout: "us-letter-10",
  marker: case-marker("technical/us-letter-10"),
)
#close-cases()
#context for look in ("technical", "soft") {
  let one = span-of(look + "/auto").pages
  assert(one == 1, message: look + ": 4 items need " + str(one) + " pages")
  let long = span-of(look + "/long").pages
  assert(
    long >= 3,
    message: look + ": the long invoice has " + str(long) + " pages",
  )
  let s = span-of(look + "/zugferd")
  let att = query(pdf.attach).filter(a => {
    let p = a.location().page()
    p >= s.first and p < s.first + s.pages
  })
  assert(att.len() == 1, message: look + ": the XML is not attached")
}
