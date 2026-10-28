// Documentation: api-reference/components.md, the examples of
// `payment-terms` (cash discount), `direct-debit`, `card-payment` and `paid`.
// The documentation shows the English texts with an illustrative amount;
// here they are printed with the number format of `locale.en-de`.

#import "/src/lib.typ": *
#import "/tests/integration/payment-reference/harness.typ": plain

// Records what the parts print, per example.
#let capturing-theme(example) = theme.plain.with(
  theme.custom.wrap("payment-terms", (ctx, view, inner) => {
    let printed = inner(ctx, view)
    [#metadata((example, "terms", plain(printed)))<printed>#printed]
  }),
  theme.custom.wrap("payment-means", (ctx, view, inner) => {
    let printed = inner(ctx, view)
    [#metadata((example, view.kind, plain(printed)))<printed>#printed]
  }),
)

#let example(name, body) = invoice(
  theme: capturing-theme(name),
  locale: locale.en-de,
  sender: (
    name: "Muster GmbH",
    address: "Hauptstraße 1",
    city: "10115 Berlin",
    vat-id: "DE123456789",
  ),
  recipient: (name: "Kunde AG", address: "Domstraße 5", city: "50667 Köln"),
  invoice-nr: "RE-1",
  date: datetime(year: 2026, month: 9, day: 1),
)[
  #line-items[#item([Consulting], price: 100, tax: tax.vat(19%))]
  #body
]

// "4. Cash Discount (Skonto)"
#example("cash-discount")[
  #payment-terms(
    days: 30,
    discount: (
      (days: 7, percent: 3%),
      (days: 14, percent: 2%, basis: 100),
    ),
  )
  #bank-details(iban: "DE89370400440532013000")
]

// `direct-debit`
#example("direct-debit")[
  #payment-terms(days: 14)
  #direct-debit(
    mandate: "M-2026-017",
    creditor-id: "DE98ZZZ09999999999",
    debtor-iban: "DE02 1203 0000 0000 2020 51",
  )
]

// `card-payment`
#example("card-payment")[
  #payment-terms()
  #card-payment(last4: "4242", holder: "Claire Martin", kind: "credit")
]

// `paid`
#example("paid")[
  #paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
]
#example("paid-card")[
  #paid(method: "card")
  #card-payment(last4: "4242", kind: "credit")
]

#context {
  let printed = (:)
  for entry in query(<printed>) {
    let (name, part, text) = entry.value
    printed.insert(name + "/" + part, text.trim().replace("\u{202f}", " "))
  }
  let expect(key, value) = assert.eq(
    printed.at(key, default: none),
    value,
    message: key + ": " + repr(printed.at(key, default: none)),
  )

  expect(
    "cash-discount/terms",
    "Please transfer the total amount of 119,00 € within 30 days to the account listed below. For payment within 7 days, a cash discount of 3% is granted. For payment within 14 days, a cash discount of 2% on 100,00 € is granted.",
  )
  expect(
    "direct-debit/terms",
    "The total amount of 119,00 € will be collected from your account by direct debit within 14 days.",
  )
  expect(
    "direct-debit/direct-debit",
    "Payment method: SEPA direct debit\nMandate reference: M-2026-017\nCreditor identifier: DE98ZZZ09999999999\nYour IBAN: DE02 1203 0000 0000 2020 51",
  )
  expect(
    "card-payment/terms",
    "The total amount of 119,00 € will be charged to your card upon receipt.",
  )
  expect(
    "card-payment/card",
    "Payment method: Credit card\nCard number: **** 4242\nCardholder: Claire Martin",
  )
  expect(
    "paid/paid",
    "The total amount of 119,00 € was paid on 01.09.2026.\nPayment method: Cash\nAmount Due: 0,00 €",
  )
  expect(
    "paid-card/paid",
    "The total amount of 119,00 € has been paid.\nAmount Due: 0,00 €",
  )
  expect(
    "paid-card/card",
    "Payment method: Credit card\nCard number: **** 4242",
  )
}
