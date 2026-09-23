// Source: docs/docs/api-reference/invoice/validation.md — "Overriding the Level from the Command Line"
// The example of "Levels" under validation: "strict" stops with the documented message.
#import "/src/lib.typ": *

#let doc(level) = invoice(
  locale: locale.en-de,
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (name: "Muster AG"), // no address
  invoice-nr: none, // missing
  zugferd: "basic",
  validation: level,
)[
  #line-items[
    #item([Corporate design concept], price: 1800)
  ]
]

#let message = catch(() => doc("strict"))
#for line in (
  "invoice-pro found 2 problems (validation: ",
  "1. invoice::invoice-nr is missing; every invoice needs a unique, sequential number (§ 14 Abs. 4 Nr. 4 UStG; EN 16931 BT-1)",
  "2. invoice::recipient has no address (`address`, `city`); the recipient's full address is required (§ 14 Abs. 4 Nr. 1 UStG; EN 16931 BG-8)",
) {
  assert(
    message.contains(line),
    message: "missing in the strict message: " + line,
  )
}

#set page(width: 160mm, height: auto, margin: 8mm)
#set text(size: 8pt)
#raw(message)
