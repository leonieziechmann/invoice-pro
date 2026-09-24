// Shared definitions of the parity fixtures (not a fixture itself).
//
// A parity fixture `<RULE>.typ` is the smallest invoice that violates one
// official rule: the official validators report the rule, and invoice-pro
// must report it under the same id (tools/zugferd/run.py checks both sides,
// see tests/TESTING.md, "Rule Coverage"). A fixture states its expectation
// like a regression case:
//
//   // expect: AGREE_INVALID <RULE>   the rules invoice-pro must report
//   // warns: <RULE>                  the rules it must report as warnings
//
// `<RULE>--<variant>.typ` shows the rule once more (e.g. in another
// profile), `<RULE>--pass.typ` is the corrected invoice, which everybody
// accepts (`// expect: AGREE_VALID`). The fixtures use the parties and the
// harness setup of the regression cases.

#import "../regression/_base.typ": *

/// A German seller identified by its seller identifier (BT-29) only, with
/// neither VAT identifier nor tax number: for the rules of the VAT
/// categories that require one of them.
#let seller-de-id = seller-de + (vat-id: none, tax-nr: none, id: "SUP-70025")

/// A seller tax representative (BG-11) in Germany.
#let representative = (
  name: "Vertreter GmbH",
  address: "Friedrichstraße 20",
  city: (name: "Berlin", post-code: "10117"),
  country: country.de,
  vat-id: "DE136695976",
)

/// One item of 100 with the given tax.
#let item-with(tax) = item([Leistung], price: 100, quantity: 1, tax: tax)

/// A standard rated item of 100 at 19 %.
#let item-s = item-with(tax.vat(19%))

/// A document level allowance (BG-20) and charge (BG-21).
#let rebate = discount([Rabatt], amount: 10%)
#let shipping = surcharge([Versand], amount: 5.90)
