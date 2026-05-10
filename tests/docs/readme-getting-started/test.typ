#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(form: "A", font: "libertinus serif"),
  locale: locale.en-de,
  sender: (
    name: "Your Company / Name",
    address: "1 Example Street",
    city: "12345 Example City",
  ),
  recipient: (
    name: "Customer Name",
    address: "5 Customer Street",
    city: "98765 Customer City",
  ),
  invoice-nr: "2026-01",
  tax-nr: "123/456/789",
)

// Add Invoice Items inside a scoped block
#line-items[
  #item(
    [Consulting & Concept],
    price: 85.00,
    quantity: 5,
    unit: "hrs",
  )

  #item(
    [Web Design Layout (Flat Rate)],
    price: 1200.00,
  )

  #item(
    [Stock Licenses (Images)],
    price: 25.00,
    quantity: 4,
  )

  #discount([Project Discount (Regular Customer)], amount: 10%)
]

// Payment Terms
#payment-goal(days: 14)

// Bank Details with QR Code
#bank-details(
  bank: "Example Bank",
  iban: "DE07100202005821158846",
  bic: "EXAMPLEBICX",
)

#signature()
