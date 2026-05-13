// Regression test for GitHub issue #19
// https://github.com/leonieziechmann/invoice-pro/issues/19
//
// Bugs reported:
// 1. Sender/recipient 'extra' field not displayed (user wrote 'extras' instead of 'extra')
// 2. Extra dictionaries with >2 items may fail to render
// 3. Item-level modifier (discount on item) silently fails
// 4. Decimal discount amount in #apply causes "locale::normalize::money is not provided"
//
// This test covers the hard edge cases:
//   - discount() and surcharge() on items via modifier: param (relative + absolute)
//   - discount() and surcharge() via #apply wrapper (relative + absolute)
//   - extra as dictionary (not content block) on both sender and recipient

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale.en-de,
  sender: (
    name: "Consulting Group LLC",
    address: "Consulting Street 1",
    city: "Berlin",
    // Bug 2: Dictionary with 3 items on sender — tests dict rendering path.
    extra: (
      "Phone": "+49 123 456789",
      "Email": "max@mustermann.de",
      "Web": "www.mustermann.de",
    ),
  ),
  recipient: (
    name: "Acme Corp",
    address: "Acme Street 1",
    city: "Munich",
    // Bug 2: Dictionary with 3 items on recipient — same rendering path.
    extra: (
      "Phone": "+49 987 654321",
      "Email": "acme@corp.de",
      "Web": "www.acme-corp.de",
    ),
  ),
  invoice-nr: "INV-2026-001",
)

#line-items(show-column: (tax-rate: true))[
  // === Item-level modifiers via modifier: param ===

  // Relative discount on item
  #item(
    [IT Consulting],
    quantity: 10,
    unit: "h",
    price: 150.00,
    modifier: discount([Loyalty Discount], amount: 10%),
  )

  // Absolute discount on item
  #item(
    [Server Audit],
    price: 1200.00,
    modifier: discount([Fixed Rebate], amount: 50),
  )

  // Relative surcharge on item
  #item(
    [Cloud Migration],
    quantity: 5,
    unit: "h",
    price: 120.00,
    modifier: surcharge([Urgency Fee], amount: 15%),
  )

  // Absolute surcharge on item
  #item(
    [Documentation],
    quantity: 1,
    price: 300.00,
    modifier: surcharge([Express Delivery], amount: 25),
  )

  // === Modifiers via #apply wrapper ===

  // Relative discount via apply
  #apply(modifier: discount([Apply Discount Rel], amount: 20%))[
    #item([Backup Service], quantity: 2, unit: "h", price: 80.00)
  ]

  // Absolute discount via apply
  #apply(modifier: discount([Apply Discount Abs], amount: 10))[
    #item([Monitoring Setup], price: 500.00)
  ]

  // Relative surcharge via apply
  #apply(modifier: surcharge([Apply Surcharge Rel], amount: 5%))[
    #item([Load Testing], quantity: 3, unit: "h", price: 100.00)
  ]

  // Absolute surcharge via apply
  #apply(modifier: surcharge([Apply Surcharge Abs], amount: 30))[
    #item([SSL Certificates], quantity: 4, price: 15.00)
  ]

  // Global discount on all line-items
  #discount([Project Discount], amount: 5%)
]

#bank-details(
  bank: "Example Bank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
