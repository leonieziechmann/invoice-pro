// expect: AGREE_VALID
// finding: legal-bt121-vatex-missing
//
// An exemption with its VATEX code (BT-121) next to the grounds (BT-120),
// and a reverse charge with the code of its category (VATEX-EU-AE), which
// is stated without input.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-VATEX",
)

#line-items[
  #item(
    [Physiotherapie],
    quantity: 2,
    unit: unit.hour,
    price: 80,
    tax: tax.exempt(
      grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
      code: "VATEX-EU-132-1C",
    ),
  )
  #item(
    [Bauleistung],
    price: 500,
    tax: tax.reverse-charge(
      grounds: "Steuerschuldnerschaft des Leistungsempfängers (§ 13b UStG)",
    ),
  )
]
#payment-goal(days: 14)
#bank
