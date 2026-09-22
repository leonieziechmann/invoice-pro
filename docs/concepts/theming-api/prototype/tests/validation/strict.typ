// Compile-fail cases of the validation levels: `--input case=N`; the expected
// panic text (lines joined) is in tests/validation/expected.txt.
// Cases 1-6 set `validation: "strict"` in the document; case 7 relies on the
// sys.inputs override (run with --input invoice-pro-validation=strict); cases
// 8-9 are misuse of the setting itself; case 10 proves misuse panics under none.
#import "/tests/body.typ": *
#let c = sys.inputs.at("case", default: "0")
#let p = party
#let drop(d, ..keys) = {
  let d = d
  for k in keys.pos() { let _ = d.remove(k) }
  d
}
#let S = (validation: "strict")
#let args = (
  "1": drop(p, "invoice-nr") + S,
  "2": drop(p, "invoice-nr")
    + S
    + (recipient: (name: "Muster AG"), sender: drop(p.sender, "vat-id")),
  "3": p + S + (zugferd: "en16931", recipient: p.recipient + (region: "at")),
  "4": p + S + (zugferd: "en16931"),
  "5": p + S,
  "6": p
    + S
    + (
      theme: theme.classic.with(
        theme.custom.page(margin: (bottom: 32mm)),
        theme.custom.area("footer", parts: (
          [#for i in range(14) [Line #i #linebreak()]],
        )),
      ),
    ),
  "7": drop(p, "invoice-nr") + (validation: "draft"),
  "8": p + (validation: "visual"),
  "9": p,
  "10": p
    + (
      validation: none,
      theme: theme.classic.with((tokens: (colors: (primry: red)))),
    ),
).at(c, default: p)
#show: invoice.with(locale: test-locale, ..args)
#if c == "5" [
  // reverse charge without the recipient's VAT ID (a measured data check)
  #line-items(tax: tax.reverse-charge())[#item([Beratung], price: 1000)]
] else if c == "4" [
  // no line items at all (and no buyer electronic address for en16931)
] else [#body()]
