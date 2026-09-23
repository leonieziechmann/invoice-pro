// Regression test for GitHub issue #28
// https://github.com/leonieziechmann/invoice-pro/issues/28
//
// Bug reported:
// Compilation panics when a tax category that sets `is-outside-scope`
// (e.g. `tax.outside-scope()`) is combined with ZUGFeRD export if the sender
// has a `vat-id` but no `tax-nr`.
//
// Under BR-O-02, the seller VAT identifier (BT-31) must be dropped when VAT
// category code (BT-151) is "Not subject to VAT" (O). In earlier versions,
// clearing `vat-id` resulted in `tax-registrations` evaluating to `none` instead
// of `()`, triggering `error: type none has no method len`.

#import "/src/lib.typ": *
#import "/src/zugferd/build.typ": (
  build-buyer-trade-party, build-seller-trade-party,
)
#import "/src/zugferd/model.typ": party-model, seller-model
#import "/src/zugferd/profile.typ": resolve-profile
#import "/src/logic/country.typ": normalize-party

// --- 1. Unit assertions on trade party building with outside-scope tax ---
#{
  let profile = resolve-profile("en16931", "DE", "US")
  let party(..fields) = normalize-party(
    (name: "Seller GmbH", address: ("Street 1",), city: "80339 München")
      + fields.named(),
    "de",
  )

  // vat-id provided, no tax-nr, is-outside-scope: true
  // Must omit SpecifiedTaxRegistration without error (not panic on none.len())
  let seller-outside-no-tax-nr = build-seller-trade-party(
    seller-model(party(vat-id: "DE123456789"), use-vat-id: false),
    profile,
  )
  assert.eq(
    seller-outside-no-tax-nr.at("ram:SpecifiedTaxRegistration", default: none),
    none,
  )
  assert.eq(
    seller-outside-no-tax-nr.at("ram:ID", default: none),
    none,
  )

  // vat-id and tax-nr provided, is-outside-scope: true
  // vat-id is dropped per BR-O-02, but tax-nr is retained as FC
  let seller-outside-with-tax-nr = build-seller-trade-party(
    seller-model(
      party(vat-id: "DE123456789", tax-nr: "123/456/78901"),
      use-vat-id: false,
    ),
    profile,
  )
  assert.eq(
    seller-outside-with-tax-nr.at(
      "ram:SpecifiedTaxRegistration",
      default: none,
    ),
    (
      ("ram:ID": ("@schemeID": "FC", "": "123/456/78901")),
    ),
  )
  assert.eq(
    seller-outside-with-tax-nr.at("ram:ID", default: none),
    "123/456/78901",
  )

  // Buyer trade party: vat-id dropped under outside-scope tax per BR-O-02
  let buyer-outside = build-buyer-trade-party(
    party-model(
      normalize-party(
        (
          name: "Buyer Inc",
          address: ("5th Ave",),
          city: (name: "New York", post-code: "10001"),
          country: country.us,
          vat-id: "DE987654321",
        ),
        "de",
      ),
      use-vat-id: false,
    ),
    profile,
  )
  assert.eq(
    buyer-outside.at("ram:SpecifiedTaxRegistration", default: none),
    none,
  )
}

// --- 2. The reported invoice no longer crashes ---
// Without the VAT ID, the seller of the reported invoice has no identifier
// left (BR-CO-26), and it has no payment terms (BR-CO-25). Both are reported
// as validation errors instead of a crash.
#let reported-invoice = invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    vat-id: "DE123456789",
    email: "seller@example.com",
  ),
  recipient: (
    name: "Buyer Inc",
    address: "5th Ave",
    city: (name: "New York", post-code: "10001"),
    country: country.us,
    email: "buyer@example.com",
  ),
  invoice-nr: "2026-01",
  tax: tax.outside-scope(grounds: "Not taxable in Germany."),
)

#{
  let message = catch(() => reported-invoice[
    #line-items[
      #item([Consulting], price: 100, quantity: 1)
    ]
  ])
  assert(
    message.starts-with("assertion failed: The e-invoice"),
    message: "Expected a validation error, got " + repr(message),
  )
  assert(message.contains("[BR-CO-26] sender:"), message: message)
  assert(message.contains("[BR-CO-25] payment-goal:"), message: message)
}

// --- 3. Full invoice rendering with an identifiable seller ---
#show: reported-invoice.with(
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    vat-id: "DE123456789",
    tax-nr: "123/456/78901",
    email: "seller@example.com",
  ),
)

#line-items[
  #item([Consulting], price: 100, quantity: 1)
]
#payment-goal(days: 14)
