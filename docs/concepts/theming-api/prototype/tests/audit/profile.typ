// en16931 between two German parties is checked as XRechnung; the message names both.
#import "/src/lib.typ": *
#show: invoice.with(
  sender: (
    name: "A GmbH",
    address: "Weg 1",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
    email: "a@b.de",
  ),
  recipient: (
    name: "B AG",
    address: "Weg 2",
    city: "80331 München",
    email: "c@d.de",
  ),
  invoice-nr: "1",
  zugferd: "en16931",
  validation: "strict",
)
#line-items[#item([X], price: 10)]
