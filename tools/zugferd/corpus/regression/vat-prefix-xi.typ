// expect: AGREE_VALID
// finding: core-codelists-cen
// facts: {"buyer_country": "GB", "buyer_vat": "XI123456789"}
//
// Goods delivered to Northern Ireland are intra-community supplies: the buyer
// has a VAT identifier with the prefix "XI" and the country is "GB". A check
// of the VAT prefix against the country must map XI to GB.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: (
    name: "Customer Ltd",
    address: "1 Example Road",
    city: (name: "Belfast", post-code: "BT1 1AA"),
    country: "GB",
    vat-id: "XI123456789",
    email: "accounts@customer.example",
  ),
  invoice-nr: "RG-VAT-PREFIX-XI",
  tax: tax.intra-community(
    grounds: "Steuerfreie innergemeinschaftliche Lieferung",
  ),
)

#line-items[
  #item([Maschinenteile], price: 1250.00, quantity: 4)
]
#payment-goal(days: 14)
#bank
