// expect: AGREE_INVALID CII-SR-449
//
// A deliver-to location with both a location identifier (BT-71) and a global
// identifier.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  delivery-address: (
    name: "Lager Client SAS",
    address: "Rue du Port 3",
    city: (name: "Lyon", post-code: "69002"),
    country: country.fr,
    id: "LAGER-7",
    global-id: id.gln("4000001987658"),
  ),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "CII-SR-449",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
