// Shared definitions of the parity fixtures (not a fixture itself).
//
// A parity fixture `<RULE>.typ` is the smallest invoice that violates one
// official rule: the official validators report the rule, and invoice-pro
// must report it under the same id (tools/zugferd/run.py checks both sides,
// see tests/TESTING.md, "Rule Coverage"). A fixture states its expectation
// like a regression case:
//
//   // expect: AGREE_INVALID <RULE>   the rules invoice-pro must report
//   // finding: <what it shows>       optional
//
// `<RULE>--<variant>.typ` shows the rule once more (e.g. in another
// profile), `<RULE>--pass.typ` is the corrected invoice, which everybody
// accepts (`// expect: AGREE_VALID`). The fixtures use the parties and the
// harness setup of the regression cases.

#import "../regression/_base.typ": *

/// A German seller with neither VAT identifier nor tax number (for the
/// rules of the VAT categories that require one of them).
#let seller-de-no-ids = seller-de + (vat-id: none, tax-nr: none)

/// A standard rated item of 100 at 19 %.
#let item-s = item([Beratung], price: 100, quantity: 1, tax: tax.vat(19%))
