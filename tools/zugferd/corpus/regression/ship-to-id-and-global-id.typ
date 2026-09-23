// expect: AGREE_INVALID CII-SR-449
// finding: verify-robustness-shipto-id-and-globalid-cii-sr-449
//
// The deliver-to location identifier (BT-71) can be given once: either `id`
// or `global-id`. Both were written without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  delivery-address: (
    name: "Client SAS Entrepôt",
    address: "1 Rue du Port",
    city: (name: "Marseille", post-code: "13002"),
    country: country.fr,
    id: "LAGER-7",
    global-id: (scheme: "0088", id: "4000001987658"),
  ),
  invoice-nr: "RG-SHIP-TO-IDS",
)

#line-items[
  #item([Ware], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
