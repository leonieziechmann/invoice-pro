// expect: STRICTER IP-TAX-01
// finding: tax-none-silently-zero-rated
//
// `tax: none` was written as category Z (zero rated goods), a tax decision
// the user never made. An e-invoice must state the VAT category, so this is
// an error in e-invoice mode (maintainer decision); plain PDFs are unchanged.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-TAX-NONE",
  tax: none,
)

#line-items[
  #item([Beratung], price: 100, quantity: 10)
]
#payment-goal(days: 14)
#bank
