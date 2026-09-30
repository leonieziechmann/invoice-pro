// expect: AGREE_VALID
// finding: core-codelists-cen
//
// The Caribbean guilder (XCG, since 2025), which the lists of Factur-X 1.0.07
// and CEN 1.3.12 in Mustang 2.14.0 lacked, so that invoice-pro reported
// BR-CL-04. Every list of Mustang 2.26.0 and KoSIT has it now: the invoice
// stays valid.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  currency: "XCG",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-CURRENCY-XCG",
)

#line-items[
  #item(
    [Pumpen],
    price: 100,
    quantity: 10,
    tax: tax.export(
      grounds: "Steuerfreie Ausfuhrlieferung nach § 4 Nr. 1 Buchst. a UStG",
    ),
  )
]
#payment-goal(days: 14)
#bank
