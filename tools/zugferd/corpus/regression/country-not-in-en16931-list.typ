// expect: AGREE_INVALID BR-CL-14
// finding: core-codelists-cen, parties-country-ss-false-negative
//
// South Sudan (SS) is missing from the country code list of the EN 16931
// validators, so an invoice stating it cannot validate. invoice-pro accepted
// it without a report.

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
