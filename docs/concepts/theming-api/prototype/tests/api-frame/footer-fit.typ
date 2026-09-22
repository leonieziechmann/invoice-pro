// Footer fit and clearance (gap 1): on every layout, with a realistic 4-line
// registration block and a 3-line contact block, the last footer line (its
// descenders included) ends at least `footer-clearance` above the sheet edge,
// on page 1 (with "Page 1 of 2") and page 2.
//   --input look=classic|corporate|boxed  --input layout=<name>  [--input margin=<mm>]
#import "/tests/body.typ": *
#let look = sys.inputs.at("look", default: "classic")
#let lay = sys.inputs.at("layout", default: "din-5008-a")
#let preset = dictionary(theme).at(look)
// every legal footer part reports where it ends (block bottom = last baseline)
#let probe(name) = theme.custom.wrap(name, (ctx, view, inner) => {
  let out = inner(ctx, view)
  if out != none {
    block(out)
    [#metadata(name)<foot-end>]
  }
})
// negative control: an explicit margin (with validation: none) must trip the probe
#let margin = sys.inputs.at("margin", default: none)
#let margin-patch = if margin != none {
  theme.custom.page(margin: (bottom: float(margin) * 1mm))
}
#let rule = theme.custom.area("footer", rule: (
  side: top,
  stroke: 0.5pt + gray,
  gap: 2mm,
))
#show: invoice.with(
  theme: preset.with(
    ..("company", "contact", "registration", "bank-account").map(probe),
    rule,
    margin-patch,
    layout: dictionary(theme.layout).at(lay),
  ),
  locale: test-locale,
  ..party,
  sender: party.sender
    + (
      tax-nr: "22/815/08154",
      management: [Geschäftsführung: Lina Berg, Jonas Petersen],
      extra: (
        Telefon: "+49 40 1234567",
        "E-Mail": "rechnung@atelier-nord-hamburg.de",
        Web: "www.atelier-nord-hamburg.de",
      ),
    ),
)
#body(n: 30)
#let check = sys.inputs.at("check", default: "1") == "1"
#if check {
  context {
    let ends = query(<foot-end>)
    assert(
      ends.len() >= 2,
      message: lay
        + ": the footer parts did not render ("
        + str(ends.len())
        + ")",
    )
    let clearance = 5mm
    let desc = measure(text(
      size: 7pt,
      top-edge: "baseline",
      bottom-edge: "descender",
    )[gjpqy]).height
    let ph = if lay in ("us-letter-10", "us-letter-digital") { 279.4mm } else {
      297mm
    }
    for e in ends {
      let y = e.location().position().y
      assert(
        y + desc <= ph - clearance + 0.05mm,
        message: lay
          + "/"
          + look
          + ": footer part "
          + e.value
          + " on page "
          + str(e.location().page())
          + " ends "
          + str(calc.round((ph - y - desc) / 1mm, digits: 2))
          + "mm above the sheet edge (clearance 5mm)",
      )
    }
    assert(
      counter(page).final().first() >= 2,
      message: lay + ": the test needs a second page",
    )
    let pages = ends.map(e => e.location().page()).dedup()
    assert(1 in pages and 2 in pages, message: lay + ": footer on both pages")
  }
}
