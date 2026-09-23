// The country of each party is the one the invoice states, on the page and in
// the e-invoice: an ISO code is honored instead of being replaced by the
// locale region, a delivery address without country is in the recipient's
// country, and invalid addresses are errors instead of silently wrong data.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/tests/data-test.typ": data-test, loom

#let seller = (
  name: "Maschinenbau GmbH",
  address: "Werkstraße 7",
  city: "70173 Stuttgart",
  country: country.de,
  vat-id: "DE123456789",
  contact: (
    name: "Export",
    phone: "+49 711 000",
    email: "export@maschinenbau.de",
  ),
)
#let buyer = (
  name: "Client SARL",
  address: "Rue du Port 3",
  city: "75002 Paris",
  country: "FR",
  vat-id: "FR40303265045",
)

/// Renders an invoice and calls `test` with the root context and the
/// e-invoice data model.
#let party-test(test, ..args) = invoice(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  zugferd-errors: "ignore",
  sender: seller,
  recipient: buyer,
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
  data-test(
    test: (ctx, data) => {
      let signal(kind) = loom.query.find-signal(data, kind)
      test(ctx, build-model(
        ctx,
        signal("line-items").item-data,
        payment-goal: signal("payment-goal"),
        bank: signal("bank-details"),
      ))
    },
    line-items[#item([Ersatzteil], price: 350)],
  ),
)

// --- 1. A country given as ISO code is honored ---
#party-test((ctx, model) => {
  assert.eq(ctx.recipient.country.code, "FR")
  assert.eq(ctx.recipient.country-explicit, true)
  // The printed address names the foreign country
  assert.eq(ctx.recipient.city, [75002 Paris \ ] + "FR - France")
  assert.eq(model.buyer.address.country, "FR")
  assert.eq(model.buyer.address.post-code, "75002")
  // DE -> FR stays EN 16931; it is no domestic XRechnung
  assert.eq(model.profile.id, "en16931")
})

#party-test(
  sender: seller + (country: [de]),
  recipient: buyer + (country: "ch", city: "8001 Zürich", vat-id: none),
  (ctx, model) => {
    assert.eq(model.seller.address.country, "DE")
    assert.eq(model.buyer.address.country, "CH")
    assert.eq(model.buyer.address.post-code, "8001")
    assert.eq(model.buyer.address.city, "Zürich")
  },
)

// A country outside the `country` module
#party-test(
  recipient: buyer
    + (
      country: country.custom(code: "NO", name: "Norge"),
      city: "0154 Oslo",
      vat-id: "NO123456789MVA",
    ),
  tax: tax.export(),
  (ctx, model) => {
    assert.eq(ctx.recipient.city, [0154 Oslo \ ] + "NO - Norge")
    assert.eq(model.buyer.address.country, "NO")
    assert.eq(model.buyer.address.post-code, "0154")
  },
)

// The older `region` key is an alias of `country`
#party-test(
  recipient: (
    name: "Eksempel AS",
    city: (name: "Oslo", post-code: "0154"),
    region: country.custom.with(code: "NO"),
  ),
  (ctx, model) => {
    assert.eq(model.buyer.address.country, "NO")
    assert.eq(ctx.recipient.country-explicit, true)
  },
)

// --- 2. Parties without country ---
// The sender gets the country of the locale; whether a country was stated is
// recorded, so that the e-invoice checks can tell a default from a statement.
#party-test(
  sender: seller + (country: auto),
  recipient: (name: "Kunde GmbH", city: "80331 München"),
  (ctx, model) => {
    assert.eq(ctx.sender.country.code, "DE")
    assert.eq(ctx.sender.country-explicit, false)
    assert.eq(ctx.recipient.country-explicit, false)
    assert.eq(model.buyer.address.country, "DE")
  },
)

// A delivery address without country is in the recipient's country
#party-test(
  tax: tax.intra-community(),
  delivery-address: (
    name: "Lager Lyon",
    address: "Rue du Port 3",
    city: "69007 Lyon",
  ),
  (ctx, model) => {
    assert.eq(ctx.delivery-address.country.code, "FR")
    assert.eq(ctx.delivery-address.country-explicit, false)
    assert.eq(ctx.delivery-address.post-code, "69007")
    assert.eq(model.ship-to.address.country, "FR")
    assert.eq(model.ship-to.address.post-code, "69007")
  },
)

// ... also when it is given on the recipient, and for custom countries
#party-test(
  recipient: buyer
    + (
      country: country.custom(code: "NO", name: "Norge"),
      city: "0154 Oslo",
      delivery-address: (name: "Lager", city: "0580 Oslo"),
    ),
  tax: tax.export(),
  (ctx, model) => {
    assert.eq(ctx.delivery-address.country.name, "Norge")
    assert.eq(model.ship-to.address.country, "NO")
    assert.eq(model.ship-to.address.post-code, "0580")
  },
)

// An explicit country of the delivery address wins
#party-test(
  delivery-address: (name: "Lager", city: "1010 Wien", country: "AT"),
  (ctx, model) => {
    assert.eq(model.ship-to.address.country, "AT")
    assert.eq(ctx.delivery-address.country-explicit, true)
  },
)

// --- 3. City lines given as content keep their spaces ---
#let plz = "70173"
#let ort = "Stuttgart"
#party-test(
  sender: seller + (city: [#plz #ort]),
  recipient: buyer + (city: [75002 *Paris*]),
  (ctx, model) => {
    assert.eq(
      (model.seller.address.post-code, model.seller.address.city),
      ("70173", "Stuttgart"),
    )
    assert.eq(
      (model.buyer.address.post-code, model.buyer.address.city),
      ("75002", "Paris"),
    )
    assert.eq(ctx.sender.city, [70173 Stuttgart \ ] + "DE - Deutschland")
  },
)

// --- 4. Invalid input is an error ---
#let fails(..args) = catch(() => party-test((ctx, model) => none, ..args))

#{
  // A delivery address must be a dictionary, also on the recipient
  let message = fails(
    recipient: buyer + (delivery-address: [Lager Leipzig \ 04109 Leipzig]),
  )
  assert(
    message.contains("`invoice::recipient.delivery-address`"),
    message: message,
  )
  let message = fails(recipient: buyer + (delivery-address: "04109 Leipzig"))
  assert(
    message.contains("`invoice::recipient.delivery-address`"),
    message: message,
  )

  // A post code must be a string: a number would lose its leading zeros
  let message = fails(
    sender: seller + (city: (name: "Dresden", post-code: 1067)),
  )
  assert(
    message.contains("`sender.city.post-code` must be a string")
      and message.contains("got 1067"),
    message: message,
  )
  let message = fails(
    delivery-address: (name: "Lager", city: (name: "Lyon", post-code: 69007)),
  )
  assert(
    message.contains("`delivery-address.city.post-code` must be a string"),
    message: message,
  )

  // A country that is not an ISO code is not replaced by the locale region
  let message = fails(recipient: buyer + (country: "Frankreich"))
  assert(
    message.contains("`recipient.country` must be a country of the `country`"),
    message: message,
  )
  let message = fails(sender: seller + (country: (name: "Deutschland")))
  assert(message.contains("`sender.country`"), message: message)
}
