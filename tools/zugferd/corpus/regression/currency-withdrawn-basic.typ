// expect: AGREE_VALID
// warns: IP-CODE-01
// finding: core-wrong-rule-ids
//
// The Bulgarian lev (BGN), which the code list of the EN 16931 Schematron
// 1.3.16 has withdrawn (Bulgaria pays in euro since 2026), in BASIC: Mustang
// validates it with the Factur-X list and CEN 1.3.12, which both still have
// it, and KoSIT does not validate BASIC. invoice-pro reported BR-CL-04, which
// no validator reports for it; as the maintainer decided, it allows the
// currency where the Factur-X validation accepts it, with a warning of its
// own rule (currency-withdrawn-from-en16931-list.typ shows EN 16931,
// currency-withdrawn-xrechnung.typ the error of XRechnung).

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
