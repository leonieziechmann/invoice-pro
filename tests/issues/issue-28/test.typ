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

// --- 1. Unit assertions on trade party building with outside-scope tax ---
#{
  // vat-id provided, no tax-nr, is-outside-scope: true
  // Must omit SpecifiedTaxRegistration without error (not panic on none.len())
  let seller-outside-no-tax-nr = build-seller-trade-party(
    "Seller GmbH",
    ("Street 1",),
    "München",
    "80339",
    "DE",
    none,
    "DE123456789",
    true,
    is-outside-scope: true,
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
    "Seller GmbH",
    ("Street 1",),
    "München",
    "80339",
    "DE",
    "123/456/78901",
    "DE123456789",
    true,
    is-outside-scope: true,
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
    "Buyer Inc",
    ("5th Ave",),
    "New York",
    "10001",
    "US",
    "DE987654321",
    true,
    is-outside-scope: true,
  )
  assert.eq(
    buyer-outside.at("ram:SpecifiedTaxRegistration", default: none),
    none,
  )
}

// --- 2. Full invoice rendering test reproducing the issue ---
#show: invoice.with(
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

#line-items[
  #item([Consulting], price: 100, quantity: 1)
]
