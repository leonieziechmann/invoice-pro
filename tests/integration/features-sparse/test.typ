#import "/src/lib.typ": *

// Sparse setup: Omitting optional fields to test defaults
#show: invoice.with(
  sender: (
    name: "Sparse Setup Corp",
    address: "1 Sparse Ln",
  ),
  recipient: (
    name: "Minimal Client",
  ),
  invoice-nr: "TEST-SPARSE-001",
)

#line-items[
  // Minimal item
  #item([Just a title])

  // Item with just a price, no quantity
  #item([Only price], price: 100)

  // Item with only total
  #item([Only total], total: 200)

  #bundle([Minimal Bundle])[
    #item([Inner item])
    #discount([Minimal Discount], amount: 10)
  ]

  #surcharge([Minimal Surcharge], amount: 5)
]

