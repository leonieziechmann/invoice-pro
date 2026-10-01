// expect: AGREE_INVALID BR-CL-14
// finding: core-codelists-cen, parties-country-ss-false-negative
//
// South Sudan (SS) is missing from the country code list of EN 16931, so
// KoSIT rejects an EN 16931 invoice stating it (BR-CL-14); Mustang 2.26.0,
// which validates EN 16931 with the Factur-X list, accepts it
// (tools/zugferd/validator-differences.toml). invoice-pro reports an error.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: (
    name: "Juba Trading Ltd",
    address: "Ministries Road 1",
    city: (name: "Juba", post-code: "00211"),
    country: country.custom(code: "SS", name: "South Sudan"),
    email: "ap@juba.example",
  ),
  invoice-nr: "RG-COUNTRY-SS",
)

#line-items[
  #item(
    [Pumpen],
    price: 100,
    quantity: 10,
    tax: tax.export(grounds: "Steuerfreie Ausfuhrlieferung"),
  )
]
#payment-goal(days: 14)
#bank
