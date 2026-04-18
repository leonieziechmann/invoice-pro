#import "@preview/invoice-pro:0.2.0": *

#let showcase(body) = {
  page(
    height: auto,
    margin: 1cm,
    invoice(theme: themes.blank, body),
  )
}

#showcase[
  #line-items[
    #bundle(
      [Software Development Project],
      description: [Full-stack development for the mobile app],
      date: (date(1, 3, 2026), date(31, 3, 2026)),
      unit: "Phase",
    )[
      #item([Backend Development], quantity: 40, unit: "hrs", price: 110.00)
      #item([Frontend Implementation], quantity: 60, unit: "hrs", price: 95.00)
      #item([Project Management], quantity: 1, unit: "flat", price: 500.00)
    ]
  ]
]


#showcase[
  #line-items(input-gross: true)[
    #item([Workstation Pro Laptop], quantity: 2, price: 2499.00)
    #item([Technical Setup], total: 150.00)

    // Absolute surcharge
    #surcharge([Express Shipping], amount: 25.00)

    // Relative discount
    #discount([Educational Discount (5%)], amount: 5%)
  ]
]

#showcase[
  #line-items[
    #item([UI Design Workshop], quantity: 1, price: 800.00)

    // Scoped tax application for multiple items
    #apply(tax: tax.lower-rate(7%))[
      #item(["Mastering Typst" - Hardcover], quantity: 3, price: 45.00)
      #item(["Design Systems" - eBook], quantity: 1, price: 29.99)
    ]

    // Single item tax override (e.g., tax-exempt service)
    #item(
      [International Consulting],
      price: 150.00,
      quantity: 5,
      tax: tax.outside-scope(),
    )
  ]
]



