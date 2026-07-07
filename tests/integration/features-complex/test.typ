#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(form: "B", font: "libertinus serif"),
  locale: locale.en-de,
  sender: (
    name: "Complex Setup Corp",
    address: "99 Complex Blvd",
    city: "54321 High Tech City",
    tax-nr: "999/888/777",
    extra: (
      "Tel": "+49 111 222333",
      "E-Mail": "hello@complex.test",
    ),
  ),
  recipient: (
    name: "Enterprise Client",
    address: "1 Big Tower",
    city: "10101 Metropolis",
  ),
  invoice-nr: "TEST-COMPLEX-001",
  tax-mode: "exclusive",
)

#line-items[
  #item(
    [Phase 1: Architecture],
    price: 150.00,
    quantity: 40,
    unit: "hrs",
  )

  #bundle([Software Development], date: (
    datetime(year: 2026, month: 1, day: 1),
    datetime(year: 2026, month: 3, day: 1),
  ))[
    #item(
      [Backend Setup],
      price: 5000.00,
      quantity: 1,
      tax: tax.lower-rate(7%),
    )
    #item(
      [Frontend Setup],
      total: 3500.00,
      input-gross: true,
    )

    // Discount on the bundle
    #discount([Development Partner Discount], amount: 5%)
  ]

  #apply(tax: tax.zero())[
    #item(
      [Tax-exempt Hosting Service],
      price: 200.00,
      quantity: 12,
      unit: "months",
    )
  ]

  // Global modifiers
  #discount([Volume Discount], amount: 10%)
  #surcharge([Express Processing Fee], amount: 250.00)
]

#payment-goal(days: 30)

#bank-details(
  bank: "Test Bank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)

#signature()
