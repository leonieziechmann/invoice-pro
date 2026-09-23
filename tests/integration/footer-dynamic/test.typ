#import "/src/lib.typ": *

#show: invoice.with(
  // The footer area replaces the 0.4 `footer:` argument; content cells are
  // woven, so the `info.*` motifs resolve in the page footer.
  theme: theme.classic.with(
    theme.custom.fonts(body: "libertinus serif"),
    theme.custom.area("footer", arrange: "stack", parts: (
      [
        #set text(8pt, fill: rgb("#666666"))
        #grid(
          columns: (1fr, 1fr, 1fr),
          [
            *#info.sender.name*           #info.sender.address           #info.sender.city
          ],
          [
            *IBAN:* #info.iban           *BIC:* #info.bic
          ],
          [
            *Invoice:* #info.invoice-nr           *Due:* #info.due-date           *Total:* #info.total.gross
          ],
        )
      ],
    )),
  ),
  locale: locale.en-de,
  sender: (
    name: "Tech Solutions GmbH",
    address: "Software Street 1",
    city: "80331 Munich",
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Global Corp",
    address: "Commerce Ave 5",
    city: "10115 Berlin",
    country: country.de,
    vat-id: "DE987654321",
    customer-nr: "CUST-9900",
  ),
  invoice-nr: "INV-2026-888",
  order-nr: "PO-4455",
  date: datetime(year: 2026, month: 8, day: 15),
)

#line-items[
  #item([Software Development], price: 150.00, quantity: 10, tax: tax.vat(19%))
]

#payment-terms(days: 14)
#bank-details(
  bank: "Global Business Bank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
