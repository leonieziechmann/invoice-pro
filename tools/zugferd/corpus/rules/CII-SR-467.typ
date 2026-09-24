// expect: AGREE_INVALID CII-SR-467
// profiles: en16931 xrechnung
//
// Two payment means with different payment means codes (BT-81): a credit
// transfer (58) and cash (10) the invoice was paid with. The CEN Schematron
// 1.3.16 of KoSIT requires one code; Mustang (CEN 1.3.12) accepts them, see
// validator-differences.toml.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "CII-SR-467",
)

#line-items[
  #item-s
]
#paid(method: "cash")
#bank
