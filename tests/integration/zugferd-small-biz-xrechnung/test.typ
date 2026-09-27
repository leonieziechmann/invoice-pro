// XRechnung of a German small business (§ 19 Abs. 1 UStG, VAT category E)
// that states only its VAT identifier, to a buyer without an email address.
// The exempt invoice keeps both VAT identifiers (BR-E-02), which identify the
// seller (BR-CO-26) and give the buyer's electronic address (BT-49,
// PEPPOL-EN16931-R010). Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "xrechnung",
  tax-exempt-small-biz: true,
  sender: (
    name: "Anna Muster Webdesign",
    address: "Hauptstraße 1",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    vat-id: "DE123456789",
    contact: (
      name: "Anna Muster",
      phone: "+49 30 1234567",
      email: "rechnung@muster-webdesign.de",
    ),
  ),
  recipient: (
    name: "Kunde AG",
    address: "Domstraße 5",
    city: (name: "Köln", post-code: "50667"),
    country: country.de,
    vat-id: "DE987654321",
    buyer-reference: "04011000-12345-34",
  ),
  invoice-nr: "KU-2026-017",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item(
    [Webdesign],
    price: 65.00,
    quantity: 12,
    unit: unit.hour,
    modifier: discount([Stammkundenrabatt], amount: 5%),
  )
  #item([Hosting], price: 9.99, quantity: 12, unit: unit.month)

  #discount([Aktionsrabatt], amount: 10%)
  #surcharge([Anfahrt], amount: 30)
]

#payment-goal(days: 14)

#bank-details(
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
