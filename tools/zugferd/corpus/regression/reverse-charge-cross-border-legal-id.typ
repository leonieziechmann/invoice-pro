// expect: STRICTER IP-VAT-226
// finding: tax-ae-buyer-legal-id-missing
//
// A cross-border reverse charge to a buyer with a legal registration
// identifier (BT-47) but no VAT identifier: BR-AE-02 accepts BT-47, but the
// VAT Directive requires the buyer VAT identifier on the invoice (Art. 226
// No. 4), which invoice-pro checks as IP-VAT-226.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr + (vat-id: none, legal-id: id.siren("987 654 324")),
  invoice-nr: "RG-AE-LEGAL-ID",
)

#line-items[
  #item(
    [Montage],
    price: 100,
    quantity: 10,
    tax: tax.reverse-charge(grounds: "Autoliquidation"),
  )
]
#payment-goal(days: 30)
#bank
