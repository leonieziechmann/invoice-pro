// expect: AGREE_INVALID BR-CL-22
// finding: legal-bt121-vatex-missing
//
// A VATEX code only the newer code list of the KoSIT validator knows
// (VATEX-EU-144): the Factur-X code list and the EN 16931 Schematron of
// Mustang reject it, so invoice-pro reports it (BR-CL-22).

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
