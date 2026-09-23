// Source: docs/docs/api-reference/theme/layouts.md — "Writing Your Own Format"
#import "/src/lib.typ": *

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

#show: invoice.with(
  theme: theme.plain.with(layout: roll, theme.custom.sizes(body: 8pt)),
  sender: (
    name: "Café Hafenblick",
    address: "Kai 1",
    city: "24103 Kiel",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
  ),
  invoice-nr: "B-0815",
)

#line-items[
  #item([Cappuccino], quantity: 2, price: 3.9)
  #item([Apple cake], price: 4.5)
]
