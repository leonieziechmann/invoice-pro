/// [ppi: 12]

// One page for a small invoice everywhere (prototype tests/one-page.typ,
// scripts/checks-fix-layouts.sh): every preset with `layout: auto` (the layout
// follows the SENDER's region) renders the shared 4-item body on exactly ONE page,
// in the region's own locale: 10 presets x 8 sender regions = 80 invoices, in
// one document (tests/theme/harness.typ). Every invoice is laid out with the
// multi-page bottom margin there, so one page here means one page alone. The
// recipient part reports the layout, which must be the preset's region layout.
#import "/tests/theme/body.typ": *
#import "/tests/theme/harness.typ": case, close-cases, spans

#let regions = ("de", "at", "ch", "fr", "it", "es", "gb", "us")
#let locales = (
  de: locale.de-de,
  at: locale.de-at,
  ch: locale.de-ch,
  fr: locale.fr-fr,
  it: locale.it-it,
  es: locale.es-es,
)
#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)
// the recipient part reports the layout it was rendered on
#let probe(key) = theme.custom.wrap("recipient", (ctx, view, inner) => {
  [#metadata((key: key, layout: ctx.theme.layout.name)) <one-page-layout>]
  inner(ctx, view)
})

#let cases = presets.map(p => regions.map(r => p + "/" + r)).join()
#for key in cases {
  let (p, r) = key.split("/")
  case(
    key,
    theme: preset-of(p).with(brand, probe(key)),
    locale: locales.at(r, default: locale.en-de),
    ..party,
    sender: party.sender + (region: r),
    body(n: 4),
  )
}
#close-cases()

#context {
  // a complete invoice: no draft report can add a page
  let open = query(<ip-issue>).map(m => m.value.id)
  assert(open == (), message: "unexpected validation issues " + repr(open))
  let lays = query(<one-page-layout>).map(m => m.value)
  let s = spans()
  assert.eq(s.map(x => x.key), cases)
  for x in s {
    let lay = lays.find(l => l.key == x.key)
    let (look, region) = x.key.split("/")
    // layout: auto followed the sender's region (set on the party here)
    assert(
      lay != none and lay.layout == auto-layout(look, region),
      message: x.key + ": rendered on " + repr(lay),
    )
    assert(
      x.pages == 1,
      message: x.key
        + " on "
        + (if lay == none { "?" } else { lay.layout })
        + ": 4 items need "
        + str(x.pages)
        + " pages, expected 1",
    )
  }
}
