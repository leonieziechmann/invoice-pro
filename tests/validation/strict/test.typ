// The validation levels under strict (prototype tests/validation/strict.typ and
// expected.txt): the compilation stops with every problem, one verbatim or
// several numbered, and misuse of the setting itself panics; messages compared
// exactly as caught panics (tytanic `catch`). Case 6 (footer fit) is found only
// after layout: tests/theme/errors checks the same finding through draft (case
// 28); case 7 relied on the --input override: its precedence is pinned here and
// in tests/validation/api.
#import "/tests/theme/body.typ": *
#import "/src/validation/issue.typ": resolve-level

#let drop(d, ..keys) = {
  let d = d
  for k in keys.pos() { let _ = d.remove(k) }
  d
}
#let p = party
#let S = (validation: "strict")
#let expected = (
  "1": "invoice::invoice-nr is missing; every invoice needs a unique, sequential number (EN 16931 BT-1)",
  "2": "invoice-pro found 3 problems (validation: \"strict\"; preview them with validation: \"draft\" or --input invoice-pro-validation=draft):\n  1. invoice::invoice-nr is missing; every invoice needs a unique, sequential number (EN 16931 BT-1)\n  2. invoice::sender has neither `vat-id` nor `tax-nr`; the supplier's VAT ID or tax number is required (EN 16931 BT-31, BT-32)\n  3. invoice::recipient has no address (`address`, `city`); the recipient's full address is required (EN 16931 BG-8)",
  "4": "invoice: the document has no line items; an invoice must state the quantity and kind of the supply (EN 16931 BG-25)",
  "5": "invoice::recipient::vat-id is missing, but the invoice applies reverse charge or an intra-community supply; the recipient's VAT ID is required (EN 16931 BT-48)",
  "8": "variable `invoice::validation`(\"visual\") must be one of none, \"draft\", \"strict\". Did you mean \"draft\"?",
  "10": "theme::tokens::colors has unknown key `primry`. Did you mean `primary`? Allowed keys: primary, on-primary, primary-text, accent, accent-text, text, text-muted, border, tint, background",
)
#let args = (
  "1": drop(p, "invoice-nr") + S,
  "2": drop(p, "invoice-nr")
    + S
    + (recipient: (name: "Muster AG"), sender: drop(p.sender, "vat-id")),
  "4": p + S + (zugferd: "en16931"),
  "5": p + S,
  "8": p + (validation: "visual"),
  "10": p
    + (
      validation: none,
      theme: theme.classic.with((tokens: (colors: (primry: red)))),
    ),
)
#let content-of(c) = if c == "5" [
  // reverse charge without the recipient's VAT ID (a measured data check)
  #line-items(tax: tax.reverse-charge())[#item([Beratung], price: 1000)]
] else if c == "4" [
  // no line items at all: the e-invoice is withheld before its rules run
] else [#body()]
#for (c, message) in expected {
  assert.eq(
    catch(() => invoice(locale: test-locale, ..args.at(c), content-of(c))),
    "panicked with: " + repr(message),
    message: "case " + c,
  )
}
// case 3: the rules of the e-invoice follow `zugferd-errors`, not the level
// (the prototype checked the data of the profile as issues): with complete
// invoice data, an XRechnung without buyer reference stops the build with the
// list of the e-invoice, as the default "panic" says (tests/zugferd)
#{
  let message = catch(() => invoice(
    locale: test-locale,
    ..einvoice-party,
    ..S,
    zugferd: "xrechnung",
    body(),
  ))
  assert(
    type(message) == str
      and message.starts-with(
        "assertion failed: The e-invoice (ZUGFeRD / Factur-X, profile XRechnung 3.0) is not valid",
      )
      and message.contains("[BR-DE-15]"),
    message: repr(message),
  )
}
// case 7: --input invoice-pro-validation=strict overrides validation: "draft"
#assert.eq(
  resolve-level("draft", inputs: (invoice-pro-validation: "strict")),
  "strict",
)
// case 9: an invalid --input value
#assert.eq(
  catch(() => resolve-level(none, inputs: (invoice-pro-validation: "strcit"))),
  "panicked with: "
    + repr(
      "--input invoice-pro-validation=strcit is not a validation level; use none, draft or strict. Did you mean `strict`?",
    ),
)
