// expect: AGREE_VALID
//
// A domestic reverse charge (e.g. section 13b UStG) identifies the buyer by
// its legal registration identifier (BT-47) instead of a VAT identifier.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-de
    + (
      vat-id: none,
      legal-id: id.register("HRB 4711", court: "Amtsgericht Köln"),
    ),
  invoice-nr: "BR-AE-02--pass",
)

#line-items[
  #item-with(
    tax.reverse-charge(
      grounds: "Steuerschuldnerschaft des Leistungsempfängers",
    ),
  )
]
#payment-goal(days: 14)
#bank
