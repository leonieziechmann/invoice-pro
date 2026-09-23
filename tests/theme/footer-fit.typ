// Footer fit fixture (prototype tests/api-frame/footer-fit.typ): a realistic
// 4-line registration block and a 3-line contact block; every legal footer part
// reports where it ends (block bottom = last baseline).
#import "/tests/theme/body.typ": *

#let probe(name) = theme.custom.wrap(name, (ctx, view, inner) => {
  let out = inner(ctx, view)
  if out != none {
    block(out)
    [#metadata(name)<foot-end>]
  }
})
#let footer-probes = (
  ("company", "contact", "registration", "bank-account").map(probe)
)
#let footer-rule = theme.custom.area("footer", rule: (
  side: top,
  stroke: 0.5pt + gray,
  gap: 2mm,
))
#let footer-sender = (
  party.sender
    + (
      tax-nr: "22/815/08154",
      management: [Geschäftsführung: Lina Berg, Jonas Petersen],
      extra: (
        Telefon: "+49 40 1234567",
        "E-Mail": "rechnung@atelier-nord-hamburg.de",
        Web: "www.atelier-nord-hamburg.de",
      ),
    )
)
/// The footer fixture: `margin` (mm) sets an explicit bottom margin.
/// -> dictionary (invoice arguments without the body)
#let footer-args(look, lay, margin: none, validation: "draft") = (
  theme: preset-of(look).with(
    ..footer-probes,
    footer-rule,
    if margin != none {
      theme.custom.page(margin: (bottom: margin * 1mm))
    },
    layout: layout-of(lay),
  ),
  locale: test-locale,
  validation: validation,
  ..party,
  sender: footer-sender,
)
