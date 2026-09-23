// A credit note (381) between German parties, written as XRechnung: positive
// amounts, the preceding invoice it credits, the amount refunded within 14
// days to the buyer's account (BG-16, required by XRechnung on credit notes
// as well). Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(),
  locale: locale.de-de,
  zugferd: "xrechnung",
  document-type: "credit-note",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@seller.de",
    ),
  ),
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    vat-id: "DE987654321",
    email: "accounting@buyer.de",
    buyer-reference: "04011000-12345-67",
  ),
  invoice-nr: "RK-2026-17",
  date: datetime(year: 2026, month: 9, day: 1),
  preceding-invoice-nr: "R-2026-11",
  references: (
    references.invoice-nr(),
    references.preceding-invoice-nr(),
    references.invoice-date(),
  ),
)

#line-items[
  #item([Returned monitor], price: 250, quantity: 2, tax: tax.vat(19%))
  #item([Goodwill discount], price: 50, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank-details(bank: "Kundenbank", iban: "DE75512108001245126199")
