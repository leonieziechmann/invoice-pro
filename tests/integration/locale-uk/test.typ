#import "/src/lib.typ": *

// 1. Standard UK Invoice with domestic sender and recipient, 20% VAT, and Sort Code bank details
#{
  let doc = invoice(
    locale: locale.en-gb,
    sender: (
      name: "Acme London Ltd",
      street: "10 Downing Street",
      city: "London SW1A 2AA",
      country: country.uk,
      vat-id: "GB123456789",
    ),
    recipient: (
      name: "Northern Client Ltd",
      street: "1 Oxford Road",
      city: "Manchester M1 5AN",
      country: country.uk,
    ),
    invoice-nr: "UK-2026-001",
    date: datetime(year: 2026, month: 9, day: 24),
  )[
    #line-items[
      #item(
        [Web Development Services],
        price: 1500.00,
        quantity: 1,
      )
      #item(
        [Home Energy Audit],
        price: 200.00,
        quantity: 1,
        tax: 5%,
      )
    ]

    #bank-details(
      name: "Acme London Ltd",
      bank: "Barclays Bank",
      sort-code: "20-00-00",
      account-number: "12345678",
    )
  ]
  [#doc]
}

// 2. UK Small Business (below VAT threshold, tax-exempt-small-biz) using locale.en-uk alias
#{
  let doc = invoice(
    locale: locale.en-uk,
    sender: (
      name: "John Smith Consulting",
      street: "221B Baker Street",
      city: "London NW1 6XE",
      country: country.uk,
    ),
    recipient: (
      name: "Global Buyer",
      street: "100 Main St",
      city: "New York, NY 10001",
      country: country.us,
    ),
    tax-exempt-small-biz: true,
    invoice-nr: "UK-SB-001",
  )[
    #line-items[
      #item(
        [Consulting Service],
        price: 500.00,
        quantity: 1,
      )
    ]

    #bank-details(
      sort-code: "112233",
      account-number: "87654321",
    )
  ]
  [#doc]
}
