#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

// Striping disabled on the classic theme
#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.fonts(body: "libertinus serif"),
    theme.custom.items-table(zebra: (none, none)),
  ),
  locale: test-locale,
  sender: (
    name: "Row Color Corp",
    address: "1 Stripe St",
  ),
  recipient: (
    name: "Minimal Client",
  ),
  invoice-nr: "TEST-ROW-COLORS-002",
)

#line-items[
  #item([First item], price: 100)

  #item(
    [Second item],
    price: 50,
    quantity: 2,
    description: [No fill on any row],
  )

  #item([Third item], price: 75, modifier: discount([Rebate], amount: 10%))

  #item([Fourth item], price: 25)
]
