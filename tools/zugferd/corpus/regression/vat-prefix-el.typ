// expect: AGREE_VALID
// finding: core-codelists-cen
// facts: {"buyer_country": "GR", "buyer_vat": "EL094014201"}
//
// Greek VAT identifiers start with "EL", although the country code is "GR"
// (BR-CO-09 allows both). An intra-community supply to Greece is valid; a
// check of the VAT prefix against the country must map EL to GR.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: (
    name: "Pelatis AE",
    address: "Odos Ermou 1",
    city: (name: "Athina", post-code: "10563"),
    country: "GR",
    vat-id: "EL094014201",
    email: "logistirio@pelatis.example",
  ),
  invoice-nr: "RG-VAT-PREFIX-EL",
  tax: tax.intra-community(
    grounds: "Steuerfreie innergemeinschaftliche Lieferung",
  ),
)

#line-items[
  #item([Maschinenteile], price: 1250.00, quantity: 4)
]
#payment-goal(days: 14)
#bank
