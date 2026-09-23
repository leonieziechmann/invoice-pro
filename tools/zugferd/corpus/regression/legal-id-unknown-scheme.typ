// expect: AGREE_INVALID BR-CL-11
// finding: parties-bt30-bt47-legal-registration-missing
//
// The scheme of a legal registration identifier (BT-30) is a code of the
// ISO/IEC 6523 ICD list (BR-CL-11); `id.custom` passes any scheme on, so the
// e-invoice checks it where it is used.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (legal-id: id.custom("9999", "4711")),
  recipient: buyer-fr,
  invoice-nr: "RG-LEGAL-SCHEME",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
