// Content is written as its plain text: styled item names and modifier
// reasons, smart quotes, line breaks and XML special characters. A name that
// is styled as a whole must not end up empty (BR-25). Validated by
// validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: [Müller & Söhne *GmbH*],
    address: ([Hauptstraße #h(1em) 1], "Hinterhaus", "2. OG", "links"),
    city: "80339 München",
    tax-nr: "123/456/78901",
    vat-id: "DE 123 456 789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@mueller.de",
    ),
  ),
  recipient: (
    name: "Buyer <Holding> GmbH",
    address: "Weg 5",
    city: "10115 Berlin",
    email: "accounting@buyer.de",
    buyer-reference: [DE123456789-12345-12],
  ),
  invoice-nr: [R&D-2026/#"07"],
  order-nr: [PO "42"],
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item(text(fill: blue)[Styled as a whole], price: 10)
  #item(["Quoted" & 'single' -- with dashes], price: 10)
  #item([Line one \ line two with *bold* and _emph_], price: 10)
  #item(
    [Fish & Chips < 5 > 3],
    price: 10,
    modifier: discount([*Happy* hour], amount: 10%),
  )
  #surcharge(text(weight: "bold")[Express], amount: 5)
]
#payment-goal(date: [within 14 days, "net"])
#bank-details(
  name: "Müller & Söhne GmbH",
  bank: "Musterbank",
  iban: "DE75 5121 0800 1245 1261 99",
  bic: "SOLADEST600",
)
