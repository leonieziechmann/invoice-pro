// expect: AGREE_VALID
// finding: legal-bt121-vatex-missing
//
// A VATEX code of 2025 (VATEX-EU-144), which only the newer list of KoSIT had
// while Mustang 2.14.0 rejected it (BR-CL-22). Every list of Mustang 2.26.0
// and KoSIT has it now: the invoice stays valid.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-VATEX-144",
)

#line-items[
  #item([Beförderung], price: 300, tax: tax.exempt(
    grounds: "Steuerfrei nach § 4 Nr. 3 UStG",
    code: "VATEX-EU-144",
  ))
]
#payment-goal(days: 14)
#bank
