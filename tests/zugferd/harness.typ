// Shared helpers of the e-invoice tests: build the data model of a small
// invoice, and look at what the validator reports and the builder writes.

#import "/src/lib.typ": *
#import "/src/zugferd/model.typ": build-model
#import "/src/zugferd/rules/engine.typ": rule-registry, run-rules
#import "/src/zugferd/build.typ": build-xml
#import "/src/logic/payment-means.typ": resolve as resolve-payment-means
#import "/tests/data-test.typ": data-test, loom

/// The payment means of rendered children, as the root context resolves
/// them: the bank details, the direct debit, the payment card and `paid`.
#let payment-means(data) = {
  let signals(kind) = loom.query.collect-signals(data, kind: kind)
  resolve-payment-means(
    signals("bank-details"),
    signals("direct-debit").first(default: none),
    signals("card-payment").first(default: none),
    signals("paid").first(default: none),
  )
}

// A German seller with every detail XRechnung asks for.
#let seller = (
  name: "Seller GmbH",
  address: "Street 1",
  city: (name: "München", post-code: "80339"),
  country: country.de,
  tax-nr: "123/456/78901",
  vat-id: "DE123456789",
  contact: (
    name: "Max Mustermann",
    phone: "+49 89 1234567",
    email: "max@seller.de",
  ),
)

// A German buyer, e.g. for XRechnung.
#let buyer-de = (
  name: "Buyer GmbH",
  address: "Weg 5",
  city: (name: "Berlin", post-code: "10115"),
  country: country.de,
  vat-id: "DE987654321",
  email: "accounting@buyer.de",
  buyer-reference: "04011000-12345-67",
)

// A French buyer, e.g. for an intra-community supply.
#let buyer-fr = (
  name: "Buyer SAS",
  address: "Rue 1",
  city: (name: "Paris", post-code: "75001"),
  country: country.fr,
  vat-id: "FR99123456789",
)

// The bank details of the seller.
#let bank = bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)

/// Renders an invoice (by default EN 16931 from Germany to France) and calls
/// `test` with the e-invoice data model built from it.
#let model-test(test, ..args, body) = invoice(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  zugferd-errors: "ignore",
  sender: seller,
  recipient: buyer-fr,
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
  ..args,
  data-test(
    test: (ctx, data) => {
      let signal(kind) = loom.query.find-signal(data, kind)
      test(build-model(
        ctx,
        signal("line-items").item-data,
        payment-goal: signal("payment-goal"),
        bank: signal("bank-details"),
        payment-means: payment-means(data),
      ))
    },
    body,
  ),
)

/// The diagnostics the validator reports for a model (`run-rules`). Each
/// must name a rule that an entry of the rule registry reports in the
/// profile of the model (its `ids`, and the profiles of the id: its
/// `id-profiles`, else the `profiles` of the entry), so that the tests check
/// the metadata the proof tools read as well.
#let diagnostics(model) = {
  let found = run-rules(model)
  for d in found {
    let listed = false
    for (key, entry) in rule-registry() {
      let profiles = entry
        .at("id-profiles", default: (:))
        .at(d.rule, default: entry.profiles)
      if (
        d.rule in entry.at("ids", default: (key,))
          and model.profile.id in profiles
      ) {
        listed = true
        break
      }
    }
    assert(
      listed,
      message: d.rule
        + " is reported in the profile "
        + model.profile.id
        + ", which no entry of the rule registry lists for it",
    )
  }
  found
}

/// The sorted rules of the diagnostics of `level` the validator reports for
/// a model.
#let rules(model, level: "error") = (
  diagnostics(model).filter(d => d.level == level).map(d => d.rule).sorted()
)

/// The first diagnostic of `rule`, or `none`.
#let diagnostic(model, rule) = diagnostics(model).find(d => d.rule == rule)

/// Every element `tag` (e.g. "ram:BilledQuantity") with its attributes and
/// text, as written in the XML the builder writes for a model.
#let xml-elements(model, tag) = {
  let elements = ()
  for part in build-xml(model).split("<" + tag).slice(1) {
    // Not another element whose name starts with `tag`
    if not (part.starts-with(">") or part.starts-with(" ")) { continue }
    elements.push(
      "<" + tag + part.split("</" + tag + ">").first() + "</" + tag + ">",
    )
  }
  elements
}

/// The text of every element `tag` (e.g. "ram:RateApplicablePercent") in the
/// XML the builder writes for a model.
#let xml-values(model, tag) = {
  let values = ()
  for element in xml-elements(model, tag) {
    values.push(element.split(">").at(1).split("<").first())
  }
  values
}
