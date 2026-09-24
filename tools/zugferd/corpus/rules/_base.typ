// Shared definitions of the parity fixtures (not a fixture itself).
//
// A parity fixture `<RULE>.typ` is the smallest invoice that violates one
// official rule: the official validators report the rule, and invoice-pro
// must report it under the same id (tools/zugferd/run.py checks both sides,
// see tests/TESTING.md, "Rule Coverage"). A fixture states its expectation
// like a regression case, and the profiles it shows the rule in:
//
//   // expect: AGREE_INVALID <RULE>   the rules invoice-pro must report
//   // warns: <RULE>                  the rules it must report as warnings
//   // profiles: basic en16931        the profiles it runs in
//
// run.py compiles a fixture once for each of its profiles, which the
// fixture passes on as `zugferd: fixture-profile("en16931")` (the argument
// is the profile of a compilation by hand). In XRechnung, a fixture whose
// buyer has no buyer reference (BT-10) reports BR-DE-15 as well.
//
// `<RULE>--<variant>.typ` shows the rule once more (e.g. with other
// inputs), `<RULE>--pass.typ` is the corrected invoice, which everybody
// accepts (`// expect: AGREE_VALID`). The fixtures use the parties and the
// harness setup of the regression cases.

#import "../regression/_base.typ": *

/// The profile of the compilation: the one run.py passes for each profile
/// of the fixture's `// profiles:` header (`--input profile=<profile>`),
/// else `default`.
#let fixture-profile(default) = sys.inputs.at("profile", default: default)

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

/// The parties of a domestic Italian invoice, for the split payment of Italy
/// (B, BR-B-01 and BR-B-02).
#let seller-it = (
  name: "Fornitore S.r.l.",
  address: "Via del Corso 10",
  city: (name: "Roma", post-code: "00186"),
  country: country.it,
  vat-id: "IT12345678903",
  contact: contact,
)
#let buyer-it = (
  name: "Cliente S.p.A.",
  address: "Corso Buenos Aires 5",
  city: (name: "Milano", post-code: "20124"),
  country: country.it,
  vat-id: "IT07654321004",
  email: "fatture@cliente.example",
  buyer-reference: "04011000-12345-34",
)

/// One item of 100 with the given tax.
#let item-with(tax) = item([Leistung], price: 100, quantity: 1, tax: tax)

/// A standard rated item of 100 at 19 %.
#let item-s = item-with(tax.vat(19%))

/// A document level allowance (BG-20) and charge (BG-21).
#let rebate = discount([Rabatt], amount: 10%)
#let shipping = surcharge([Versand], amount: 5.90)

/// A document level allowance and charge of their own VAT category, e.g.
/// next to lines of another one.
#let rebate-with(tax) = discount([Rabatt], amount: 10, tax: tax)
#let shipping-with(tax) = surcharge([Versand], amount: 5.90, tax: tax)
