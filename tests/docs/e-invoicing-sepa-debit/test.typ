// Documentation: e-invoicing.md, "Direct Debit". An XRechnung collected by
// SEPA direct debit: the payment goal announces the debit, and the e-invoice
// states the mandate reference, the creditor identifier and the debited
// account. Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale.en-de,
  zugferd: "xrechnung",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@consultinggroup.de",
    ),
  ),
  recipient: (
    name: "Acme Corp",
    address: "Industrial Road 1",
    city: (name: "Stuttgart", post-code: "70173"),
    country: country.de,
    email: "invoices@acme.example",
    buyer-reference: "04011000-12345-67",
  ),
  invoice-nr: "INV-2026-104",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Maintenance contract, September], price: 250)
]

// "The total amount of 297,50 € will be collected from your account by
// direct debit within 14 days."
#payment-goal(days: 14)

#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98ZZZ09999999999",
  debtor-iban: "DE02 1203 0000 0000 2020 51",
)
