// A small invoice fits on ONE page everywhere: every preset with `layout: auto`
// (the layout follows the SENDER's region) renders the shared body with n items
// (tests/body.typ, default 4) on exactly one page, in the region's own locale.
//   --input look=<preset> --input region=de|at|ch|fr|it|es|gb|us [--input n=4]
//   --input layout=<name>  an explicit layout instead of auto (e.g. sn-010130-left)
//   --input check=0  renders without the assertion (to look at a failing case)
#import "/tests/body.typ": *
#let look = sys.inputs.at("look", default: "classic")
#let region = sys.inputs.at("region", default: "de")
#let n = int(sys.inputs.at("n", default: "4"))
#let lay = sys.inputs.at("layout", default: "auto")
#let loc = (
  de: locale.de-de,
  at: locale.de-at,
  ch: locale.de-ch,
  fr: locale.fr-fr,
  it: locale.it-it,
  es: locale.es-es,
).at(region, default: locale.en-de)
#let probe = theme.custom.wrap("recipient", (ctx, view, inner) => {
  [#metadata(ctx.theme.layout.name) <one-page-layout>]
  inner(ctx, view)
})
#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)
#show: invoice.with(
  theme: dictionary(theme)
    .at(look)
    .with(brand, probe, layout: if lay == "auto" { auto } else {
      dictionary(theme.layout).at(lay)
    }),
  locale: loc,
  ..party,
  sender: party.sender + (region: region),
)
#body(n: n)
#if sys.inputs.at("check", default: "1") == "1" {
  context {
    let pages = counter(page).final().first()
    let lay = query(<one-page-layout>).map(m => m.value).at(0, default: "?")
    assert(
      pages == 1,
      message: look
        + " / "
        + region
        + " on "
        + lay
        + ": "
        + str(n)
        + " items need "
        + str(pages)
        + " pages, expected 1",
    )
  }
}
