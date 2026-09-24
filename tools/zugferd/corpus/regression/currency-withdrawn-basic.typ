// expect: STRICTER IP-CODE-01
// finding: core-wrong-rule-ids
//
// The Bulgarian lev (BGN), which the code list of the EN 16931 Schematron
// 1.3.16 has withdrawn (Bulgaria pays in euro since 2026), in BASIC: Mustang
// validates it with the Factur-X list and CEN 1.3.12, which both still have
// it, and KoSIT does not validate BASIC. invoice-pro reported BR-CL-04, which
// no validator reports for it; it now reports its own rule
// (currency-withdrawn-from-en16931-list.typ shows BR-CL-04 in EN 16931).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic",
  currency: "BGN",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "RG-CURRENCY-BGN-BASIC",
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
