// expect: AGREE_INVALID CII-SR-470
// profiles: basic-wl basic en16931
//
// An invoice paid by credit transfer without the account (BT-84): the CEN
// Schematron 1.3.16 (Mustang and KoSIT) and Factur-X 1.09 (Mustang) require
// its IBAN or proprietary ID.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "CII-SR-470",
)

#line-items[
  #item-s
]
#paid(method: "transfer")
