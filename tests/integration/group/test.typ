#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(form: "B", font: "libertinus serif"),
  locale: locale.en-de,
  sender: (
    name: "Acme Consulting GmbH",
    address: "Musterstr. 10",
    city: "10115 Berlin",
    tax-nr: "123/456/789",
    extra: (
      "Tel": "+49 30 1234567",
      "E-Mail": "contact@acme.test",
    ),
  ),
  recipient: (
    name: "Global Enterprise Ltd",
    address: "Tech Park 42",
    city: "80331 Munich",
  ),
  invoice-nr: "INV-2026-GRP-001",
  tax-mode: "exclusive",
)

#line-items[
  #item(
    [Project Setup & Architecture],
    price: 500.00,
    quantity: 1,
  )

  #group(
    [Phase 1: Discovery & Conception],
    description: [Initial requirement gathering and UX architecture],
  )[
    #item(
      [Stakeholder Interviews],
      price: 150.00,
      quantity: 8,
      unit: "hrs",
    )
    #item(
      [Requirements Specification],
      price: 800.00,
      quantity: 1,
    )

    #group(
      [Subgroup: UI/UX Prototyping],
      description: [Visual design and interactive wireframes],
    )[
      #item([Wireframing], price: 350.00, quantity: 1)
      #item([Design System Setup], price: 450.00, quantity: 1)
      #item([Interactive Prototype], price: 600.00, quantity: 1)
      #item([User Testing & Review], price: 400.00, quantity: 1)
    ]
  ]

  #group(
    [Phase 2: Development],
    description: [Implementation and automated testing],
    show-subtotal: false,
  )[
    #item(
      [Core Backend API],
      price: 2500.00,
      quantity: 1,
    )
    #bundle([Asset & Integration Bundle])[
      #item([Payment Gateway Integration], price: 800.00)
      #item([Email Service Setup], price: 300.00)
    ]
  ]

  #item(
    [Deployment & Handover],
    price: 600.00,
    quantity: 1,
  )
]
