// expect: AGREE_INVALID BR-CL-26
// finding: core-wrong-rule-ids
//
// An unknown scheme of the deliver-to location identifier violates BR-CL-26;
// invoice-pro reported it as BR-CL-10 (the rule of the seller and buyer
// identifiers), which the official validators do not name.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  delivery-address: (
    name: "Lager",
    address: "Rue 9",
    city: (name: "Lyon", post-code: "69001"),
    country: country.fr,
    global-id: (scheme: "9999", id: "4000001123452"),
  ),
  invoice-nr: "RG-SHIP-TO-SCHEME",
  tax: tax.reverse-charge(),
)

#line-items[
  #item([Beratung], price: 100, quantity: 10)
]
#payment-goal(days: 14)
#bank
