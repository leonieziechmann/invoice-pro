// Small business exemption (§ 19 Abs. 1 UStG, VAT category E) with an item
// discount and document level allowances/charges. Exempt amounts carry the
// VAT rate 0 (BR-E-05, BR-E-06, BR-E-07), and the seller keeps its VAT
// identifier and tax number (BR-E-02, BR-E-03, BR-E-04). Validated by
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
