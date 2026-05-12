// Full-feature line-items calculation test
//
// This test exercises every feature of the line-items system together:
//   - Standalone items with different tax rates
//   - Item-level modifiers (per-item discount and surcharge)
//   - Bundles that aggregate child items into virtual items
//   - Bundle-level discount (applied inside the bundle scope)
//   - Global percentage discount
//   - Global absolute surcharge
//
// Scenario (all prices are net / tax-exclusive):
//
//   ┌─────────────────────────────────────────────────────────┐
//   │ Standalone Items                                       │
//   ├─────────────────────────────────────────────────────────┤
//   │ Item A: 100.00 × 2 = 200.00 @ 19% VAT                │
//   │   └─ item discount: -10% → -20.00                     │
//   │   └─ modified total: 180.00                           │
//   │                                                         │
//   │ Item B: total = 500.00 @ 7% lower-rate                │
//   │   └─ item surcharge: +25.00                           │
//   │   └─ modified total: 525.00                           │
//   ├─────────────────────────────────────────────────────────┤
//   │ Bundle "Development" (quantity: 1)                     │
//   │   Item C: 300.00 × 1 = 300.00 @ 19% VAT              │
//   │   Item D: 150.00 × 1 = 150.00 @ 7% lower-rate        │
//   │   Bundle discount: -50.00 absolute                    │
//   │                                                         │
//   │   Bundle produces virtual items per tax bracket:       │
//   │     19% bracket base: 300.00                          │
//   │       discount split: -50 × (300/450) = -33.33        │
//   │       virtual total: 300.00 - 33.33 = 266.67          │
//   │     7% bracket base: 150.00                           │
//   │       discount split: -50 × (150/450) = -16.67        │
//   │       virtual total: 150.00 - 16.67 = 133.33          │
//   ├─────────────────────────────────────────────────────────┤
//   │ Item E (zero-rated): total = 100.00 @ 0%              │
//   ├─────────────────────────────────────────────────────────┤
//   │ Global discount: -5%                                   │
//   │ Global surcharge: +30.00 absolute                     │
//   └─────────────────────────────────────────────────────────┘
//
// Step 1: Items entering modifier-applicator (after item-level mods,
//         after bundle aggregation):
//
//   19% group: Item A (180.00) + Bundle-19% (266.67) = 446.67
//    7% group: Item B (525.00) + Bundle-7%  (133.33) = 658.33
//    0% group: Item E (100.00)                       = 100.00
//   Subtotal (net before global modifiers):          = 1205.00
//
// Step 2: Global 5% discount per tax group:
//   19% discount: 446.67 × 5%  = -22.33
//    7% discount: 658.33 × 5%  = -32.92
//    0% discount: 100.00 × 5%  = -5.00
//   Total discount:             = -60.25
//
// Step 3: Global 30.00 absolute surcharge split proportionally:
//   Base total = 1205.00
//   19% share: 30 × (446.67 / 1205) ≈ 11.12
//    7% share: 30 × (658.33 / 1205) ≈ 16.39
//    0% share: 30 × (100.00 / 1205) ≈  2.49
//   (Rounding remainder goes to largest group, 7%)
//   Total surcharge:                   = 30.00
//
// Step 4: Net totals after global modifiers:
//   19% net: 446.67 - 22.33 + 11.12   = 435.46
//    7% net: 658.33 - 32.92 + 16.39   = 641.80
//    0% net: 100.00 -  5.00 +  2.49   =  97.49
//   Net total:                         = 1174.75
//
// Step 5: Tax:
//   19% tax: 435.46 × 0.19            = 82.74
//    7% tax: 641.80 × 0.07            = 44.93
//    0% tax:                           =  0.00
//   Total tax:                         = 127.67
//
// Step 6: Gross total:
//   1174.75 + 127.67                   = 1302.42

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
    decimal("1174.75"),
    message: "Net total: expected 1174.75, got " + repr(li.total.net),
  )

  // ---- Gross total ----
  assert.eq(
    li.total.gross,
    decimal("1302.42"),
    message: "Gross total: expected 1302.42, got " + repr(li.total.gross),
  )
})[
  #line-items[
    // ── Standalone Item A: with item-level percentage discount ──
    #item(
      [Consulting],
      price: 100.00,
      quantity: 2,
      tax: tax.vat(19%),
      modifier: discount([Loyalty Discount], amount: 10%),
    )

    // ── Standalone Item B: with item-level absolute surcharge ──
    #item(
      [Content Production],
      total: 500.00,
      tax: tax.lower-rate(7%),
      modifier: surcharge([Rush Delivery], amount: 25.00),
    )

    // ── Bundle: mixed tax brackets with bundle-level discount ──
    #bundle([Development])[
      #item(
        [Backend Implementation],
        price: 300.00,
        quantity: 1,
        tax: tax.vat(19%),
      )

      #item(
        [Documentation],
        price: 150.00,
        quantity: 1,
        tax: tax.lower-rate(7%),
      )

      // Discount applied within the bundle scope
      #discount([Partner Discount], amount: 50.00)
    ]

    // ── Standalone Item E: zero-rated ──
    #item(
      [Tax-exempt Service],
      total: 100.00,
      tax: tax.zero(),
    )

    // ── Global modifiers ──
    #discount([Seasonal Discount], amount: 5%)
    #surcharge([Administrative Fee], amount: 30.00)
  ]
]
