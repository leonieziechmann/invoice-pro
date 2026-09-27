// expect: AGREE_VALID
// finding: parties-payee-bt85-missing
// facts: {"payee": {"name": "Factoring Bank AG", "ids": [["0088", "4000001543212"]], "legal_id": ["", "Amtsgericht Frankfurt am Main, HRB 12345"]}}
//
// A seller that sold its receivables to a factoring company, which receives
// the payment (payee, BG-10). There was no input for it: the XML told the
// buyer to pay the seller, while the printed invoice named the factor.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  payee: (
    name: "Factoring Bank AG",
    global-id: id.gln("4000001543212"),
    legal-id: id.register(
      "HRB 12345",
      court: "Amtsgericht Frankfurt am Main",
    ),
  ),
  invoice-nr: "RG-PAYEE",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 30)
#bank-details(
  name: "Factoring Bank AG",
  bank: "Factoring Bank AG",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
