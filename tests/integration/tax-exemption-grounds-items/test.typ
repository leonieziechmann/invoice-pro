// Items of one VAT category exempt for different reasons: every ground is
// printed below the line items, and each item is marked with its own ground
// in the tax column (docs/docs/api-reference/tax.md, "The grounds parameter").
#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

#show: invoice.with(
  theme: themes.blank,
  locale: test-locale,
  sender: (name: "Praxis Dr. Muster", address: "Street 1", city: "City"),
  recipient: (name: "Client", address: "Street 2", city: "City"),
  invoice-nr: "2026-07",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item(
    [Medical treatment],
    price: 90.00,
    tax: tax.exempt(grounds: "Steuerfrei nach § 4 Nr. 14 UStG"),
  )
  #item(
    [First aid seminar],
    price: 300.00,
    tax: tax.exempt(grounds: "Steuerfrei nach § 4 Nr. 21 UStG"),
  )
  #item([Book], price: 20.00, tax: tax.vat(7%))
]
