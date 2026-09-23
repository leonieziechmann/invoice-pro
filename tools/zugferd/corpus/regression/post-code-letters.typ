// expect: AGREE_VALID
// finding: parties-postcode-parsing-wrong
// facts: {"buyer_post_code": "1012 AB", "buyer_city_name": "Amsterdam"}
//
// A Dutch city line "1012 AB Amsterdam" was split into post code "1012" and
// city "AB Amsterdam". Fixed with the post code formats per country; kept as
// a regression case.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: (
    name: "Klant BV",
    address: "Damrak 1",
    city: "1012 AB Amsterdam",
    country: "NL",
    vat-id: "NL123456782B01",
    email: "factuur@klant.example",
  ),
  invoice-nr: "RG-POST-CODE-NL",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
