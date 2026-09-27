// expect: AGREE_VALID
// finding: parties-identifier-inputs-dropped
// facts: {"seller_ids": [["0088", "4000001123452"]]}
//
// A seller `id` in the dictionary form of `global-id` (scheme and id) was
// silently dropped: the XML had no seller identifier (BT-29).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (id: (scheme: "0088", id: "4000001123452")),
  recipient: buyer-de,
  invoice-nr: "RG-SELLER-ID-DICT",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
