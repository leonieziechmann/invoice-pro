#import "/src/lib.typ": *

#show: invoice.with(
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
  invoice-nr: "INV-2026-99",
  order-nr: "PO-7788",
  date: datetime(year: 2026, month: 8, day: 15),
)

#line-items[
  #item(
    [Software Architecture Consulting],
    price: 1000.00,
    quantity: 2,
    tax: tax.vat(19%),
  )
]

#payment-goal(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)

== Dynamic Context Verification with Info Module

- Region Code: #info.dynamic("locale", "region", "code")
- Sender Name: #info.sender.name
- Recipient Name: #info.recipient.name
- Invoice Number: #info.invoice-nr
- Order Number: #info.order-nr
- Customer Number: #info.customer-nr
- Invoice Date: #info.invoice-date
- Calculated Due Date: #info.due-date
- IBAN: #info.iban
- Total Gross: #info.total.gross
- Custom Dynamic Query: #info.get("sender", "tax-nr")
- Closure Query: #info.dynamic(ctx => [Custom Closure: #ctx.sender.name -> #ctx.recipient.name])
