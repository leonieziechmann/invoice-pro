// expect: AGREE_VALID
// finding: legal-date-of-supply-not-printed
// facts: {"type_code": "386"}
//
// A prepayment invoice (386) asks for an advance payment before the supply:
// its own date is not the date of the supply, so neither the printed invoice
// nor the XML states one (no BT-72). A seller in Germany need not print one
// either (§ 14 Abs. 5 UStG asks for the date of the payment only if it is
// known), so the DIN 5008 letter with the default references is a legal
// invoice without findings (IP-PERIOD-03 does not apply).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  theme: harness(theme.classic.with(
    theme.custom.fonts(body: "libertinus serif"),
    // the DIN 5008 letter of 0.4 had no legal footer, which would print the
    // seller's VAT ID and tax number
    theme.custom.area("footer", none),
  )),
  zugferd: "en16931",
  document-type: "prepayment",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "AR-2026-01",
)

#line-items[
  #item([Anzahlung Dachsanierung], price: 3000)
]
#payment-terms(days: 14)
#bank
