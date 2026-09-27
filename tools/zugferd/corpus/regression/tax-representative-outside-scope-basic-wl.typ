// expect: STRICTER IP-TAX-05
// finding: core-wrong-rule-ids
//
// An invoice not subject to VAT (O) that names a seller tax representative
// in BASIC WL, without allowances or charges: BASIC WL has no lines, so no
// BR-O-02, and its validation accepts the representative's VAT identifier
// (BT-63). invoice-pro reported BR-O-02, a rule the profile does not have; it
// now reports its own rule, as EN 16931 excludes the identifier for items not
// subject to VAT (tax-representative-outside-scope.typ shows EN 16931).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
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
  invoice-nr: "RG-TAX-REP-O-BWL",
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
