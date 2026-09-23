// Small business exemption (§ 19 UStG, VAT category O) with an item discount
// and document level allowances/charges. Amounts not subject to VAT carry no
// VAT rate (BR-O-05, BR-O-06, BR-O-07), and the seller is identified by its
// tax number, since VAT identifiers are left out (BR-O-02). Validated by
// validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  tax-exempt-small-biz: true,
  sender: (
    name: "Kleinunternehmer e.K.",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 123 456789",
      email: "max@mustermann.de",
    ),
  ),
  recipient: (
    name: "Kunde AG",
    address: "Kundenweg 5",
    city: "54321 Kundenstadt",
    buyer-reference: "DE123456789-12345-12",
    email: "accounting@kunde.de",
  ),
  invoice-nr: "ZUG-KLEIN-2026-002",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item(
    [Dienstleistung],
    price: 150.00,
    quantity: 4,
    unit: unit.hour,
    modifier: discount([Stammkundenrabatt], amount: 5%),
  )
  #item([Produkt], price: 25.00, quantity: 10, unit: unit.piece)

  #discount([Aktionsrabatt], amount: 10%)
  #surcharge([Anfahrt], amount: 30)
]

#payment-goal(days: 14)

#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
