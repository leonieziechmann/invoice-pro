// expect: AGREE_VALID
// finding: parties-bt30-bt47-legal-registration-missing
// facts: {"profile": "xrechnung", "buyer_reference": "04011000-1234512345-06"}
//
// The Leitweg-ID of the `id` module, checked for its check digits, is the
// buyer reference (BT-10) and the electronic address of the buyer (BT-49,
// scheme 0204) of an XRechnung to a public buyer without VAT identifier.

#import "_base.typ": *

#let leitweg = id.leitweg("04011000-1234512345-06")

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: (
    name: "Stadt Musterstadt",
    address: "Rathausplatz 1",
    city: (name: "Musterstadt", post-code: "12345"),
    country: country.de,
    leitweg-id: leitweg,
    electronic-address: leitweg,
  ),
  invoice-nr: "RG-LEITWEG",
)

#line-items[
  #item([Wartung], price: 100, quantity: 12, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank
