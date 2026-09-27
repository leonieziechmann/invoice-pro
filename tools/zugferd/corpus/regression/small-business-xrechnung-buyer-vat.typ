// expect: AGREE_VALID
// finding: robustness-smallbiz-buyer-eaddr-not-derived
//
// A small business XRechnung to a buyer with a VAT identifier but without an
// e-mail address: the buyer's electronic address (BT-49) comes from the VAT
// identifier, which the small business scheme does not forbid. invoice-pro
// reported PEPPOL-EN16931-R010 instead.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de + (vat-id: none),
  recipient: buyer-de + (email: none),
  invoice-nr: "RG-SMALLBIZ-XR",
  tax-exempt-small-biz: true,
)

#line-items[
  #item([Beratung], price: 100, quantity: 10)
]
#payment-goal(days: 14)
#bank
