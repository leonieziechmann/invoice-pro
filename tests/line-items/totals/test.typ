// Complex line-items calculation test
//
// Scenario (all prices are net / tax-exclusive):
//   Item A: 150.00 × 3  = 450.00  @ 19% VAT
//   Item B: 200.00 × 2  = 400.00  @ 19% VAT
//   Item C:  80.00 × 5  = 400.00  @  7% VAT (lower rate)
//   Item D: total=250.00          @  0% VAT (zero-rated)
//
//   Global discount: 10% (percentage)
//   Global surcharge: 50.00 (absolute)
//
// Expected calculation (exclusive / net-based):
//
//   --- Before modifiers ---
//   19% group total: 450 + 400          = 850.00
//    7% group total:                     = 400.00
//    0% group total:                     = 250.00
//   Subtotal (net):                      = 1500.00
//
//   --- 10% discount applied per tax group ---
//   19% discount: 850.00 × 10%          = -85.00
//    7% discount: 400.00 × 10%          = -40.00
//    0% discount: 250.00 × 10%          = -25.00
//   Total discount:                      = -150.00
//
//   --- 50.00 absolute surcharge split proportionally ---
//   Base total = 1500.00
//   19% share: 50 × (850/1500)  ≈ 28.33  (rounded to 2 decimals)
//    7% share: 50 × (400/1500)  ≈ 13.33
//    0% share: 50 × (250/1500)  ≈  8.33
//   Rounding remainder (0.01) goes to largest group (19%): 28.34
//   Total surcharge:                     = 50.00
//
//   --- Net totals after modifiers ---
//   19% net: 850 - 85 + 28.34           = 793.34
//    7% net: 400 - 40 + 13.33           = 373.33
//    0% net: 250 - 25 +  8.33           = 233.33
//   Net total:                           = 1400.00
//
//   --- Tax ---
//   19% tax: 793.34 × 0.19              = 150.73 (rounded)
//    7% tax: 373.33 × 0.07              =  26.13 (rounded)
//    0% tax:                             =   0.00
//   Total tax:                           = 176.86
//
//   --- Gross total ---
//   1400.00 + 176.86                     = 1576.86

#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test, loom
#import "/tests/test-locale.typ": test-locale

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Test Sender", address: "Street 1", city: "City"),
  recipient: (name: "Test Recipient", address: "Street 2", city: "City"),
  tax-mode: "exclusive",
)

#data-test(test: (ctx, data) => {
  let li = loom.query.find-signal(data, "line-items")

  // ---- Net total ----
  assert.eq(
    li.total.net,
    decimal("1400"),
    message: "Net total: expected 1400.00, got " + repr(li.total.net),
  )

  // ---- Gross total ----
  assert.eq(
    li.total.gross,
    decimal("1576.86"),
    message: "Gross total: expected 1576.86, got " + repr(li.total.gross),
  )
})[
  #line-items[
    // Item A: standard rate, quantity pricing
    #item(
      [Item A — Standard],
      price: 150.00,
      quantity: 3,
      tax: tax.vat(19%),
    )

    // Item B: standard rate, different price
    #item(
      [Item B — Standard],
      price: 200.00,
      quantity: 2,
      tax: tax.vat(19%),
    )

    // Item C: lower tax rate
    #item(
      [Item C — Reduced Rate],
      price: 80.00,
      quantity: 5,
      tax: tax.vat(7%),
    )

    // Item D: zero-rated, using total instead of price×quantity
    #item(
      [Item D — Zero Rated],
      total: 250.00,
      tax: tax.zero(),
    )

    // Global 10% discount
    #discount([Volume Discount], amount: 10%)

    // Global absolute surcharge
    #surcharge([Handling Fee], amount: 50.00)
  ]
]
