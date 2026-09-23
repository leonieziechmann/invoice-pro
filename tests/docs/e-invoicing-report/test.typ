// Documentation: e-invoicing.md, "Custom Report Layout". The invoice misses
// its payment terms, so `zugferd-errors: "report"` hands the problem to the
// theme's `zugferd-report` function instead of failing.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes
    .DIN-5008(font: "libertinus serif")
    .with(
      zugferd-report: (ctx, result) => {
        for d in result.diagnostics [
          - *#d.rule* (#d.level): #d.message
        ]
      },
    ),
  zugferd: "en16931",
  zugferd-errors: "report",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
    tax-nr: "143/123/45678",
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
    vat-id: "DE987654321",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "INV-2026-103",
  date: datetime(year: 2026, month: 7, day: 8),
)

#line-items[
  #item(
    [Senior Software Development],
    quantity: 40,
    unit: unit.hour,
    price: 120.00,
  )
]

#bank-details(
  bank: "Global Business Bank",
  iban: "DE89370400440532013000",
  bic: "GBBADEFFXXX",
)
