// expect: AGREE_VALID
// finding: parties-payee-bt85-missing
// facts: {"account_name": "Factoring Bank AG", "iban": "DE89370400440532013000"}
//
// The account holder given to `bank-details` is the account name (BT-85).
// It was printed and encoded in the EPC-QR code, but not written.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "RG-KONTONAME",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank-details(name: "Factoring Bank AG", iban: "DE89370400440532013000")
