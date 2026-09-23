// expect: AGREE_INVALID BR-O-02
// finding: parties-bg11-tax-representative-missing
//
// An invoice not subject to VAT (O) states no VAT identifiers (BR-O-02), so
// it cannot name a seller tax representative (BG-11), whose VAT identifier
// (BT-63) it would have to state (BR-56).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de
    + (
      tax-representative: (
        name: "Fiskalvertretung Muster GmbH",
        address: "Steuerweg 3",
        city: (name: "Frankfurt am Main", post-code: "60311"),
        country: country.de,
        vat-id: "DE987654328",
      ),
    ),
  recipient: buyer-us,
  invoice-nr: "RG-TAX-REP-O",
)

#line-items[
  #item(
    [Beratung],
    price: 100,
    quantity: 10,
    tax: tax.outside-scope(grounds: "Nicht im Inland steuerbare Leistung"),
  )
]
#payment-goal(days: 30)
#bank
