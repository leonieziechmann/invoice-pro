// expect: AGREE_INVALID BR-CL-26
//
// A deliver-to location identifier (BT-71) with a scheme that is no ISO/IEC
// 6523 code.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  delivery-address: (
    name: "Lager Client SAS",
    address: "Rue du Port 3",
    city: (name: "Lyon", post-code: "69002"),
    country: country.fr,
    global-id: (scheme: "9999", id: "4711"),
  ),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-26",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
