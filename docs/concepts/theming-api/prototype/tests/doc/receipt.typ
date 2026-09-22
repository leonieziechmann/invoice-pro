#import "prelude.typ": *
// Any format is data: an 80 mm thermal-roll receipt (continuous page)
#let roll = (
  name: "roll-80",
  paper: (width: 80mm, height: auto),
  marks: none,
  margin: (x: 4mm, top: 6mm, bottom: 16mm),
  areas: (
    letterhead: (place: "before", parts: ("sender",), align: center),
    title: (place: "before", parts: ("title",)),
    address: (place: "before", parts: ("recipient",)),
    footer: (place: "footer", parts: ("registration",), text: (size: 6pt)),
  ),
)
#show: invoice.with(locale: locale.de-de, ..party, theme: theme.plain.with(
  layout: roll,
  theme.custom.sizes(body: 8pt, fine: 6pt),
  theme.custom.title(show-place-date: true),
))
#body(n: 3)
