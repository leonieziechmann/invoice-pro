// expect: AGREE_INVALID CII-SR-470
// profiles: en16931
//
// An invoice paid by credit transfer without the account (BT-84): the CEN
// Schematron 1.3.16 of KoSIT requires its IBAN or proprietary ID. Mustang
// (CEN 1.3.12, whose BR-61 tests the debited account) accepts it, see
// validator-differences.toml.

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
