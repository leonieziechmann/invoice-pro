// expect: AGREE_VALID
// finding: parties-country-string-silently-replaced
// facts: {"buyer_country": "GB", "buyer_vat": "GB123456789"}
//
// "UK" is the common name, not the ISO code of the United Kingdom: a country
// given as "UK" is written as "GB" (BT-55). It was replaced by the country of
// the locale; kept as a regression case, as are the VAT prefixes EL and XI.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: (
    name: "Customer Ltd",
    address: "1 Example Road",
    city: (name: "London", post-code: "EC1A 1BB"),
    country: "UK",
    vat-id: "GB123456789",
    email: "accounts@customer.example",
  ),
  invoice-nr: "RG-COUNTRY-UK",
  tax: tax.export(grounds: "Steuerfreie Ausfuhrlieferung"),
)

#line-items[
  #item([Maschinenteile], price: 1250.00, quantity: 4)
]
#payment-goal(days: 14)
#bank
