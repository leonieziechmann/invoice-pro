// Factur-X EN 16931 with gross prices (`tax-mode: "inclusive"`): the XML
// states net amounts. Every line and allowance is converted to net on its own,
// and the rounding difference moves onto the largest line of its VAT category,
// so the lines add up to the printed taxable amounts (BR-S-08, BR-CO-10,
// BR-CO-13) and the XML totals equal the printed ones. Validated by
// validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  tax-mode: "inclusive",
  sender: (
    name: "Shop GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "shop@example.de",
    ),
  ),
  recipient: (
    name: "Erika Musterfrau",
    address: "Mariahilfer Straße 1",
    city: (name: "Wien", post-code: "1060"),
    country: country.at,
    email: "erika@example.at",
  ),
  invoice-nr: "2026-B2C-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Shirt], price: 19.99, quantity: 3)
  #item([Book], price: 12.00, quantity: 1, tax: tax.vat(7%))
  #item(
    [Hat],
    price: 10.00,
    quantity: 1,
    modifier: discount([Sale], amount: 10%),
  )

  #discount([Coupon], amount: 5.00)
  #prepayment(20)
]
#payment-goal(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
