#import "prelude.typ": *
// draft (the default): the invoice renders, the gaps are marked, a report page follows
#show: invoice.with(
  locale: locale.de-de,
  ..party,
  invoice-nr: none, // missing: ‹fehlt: Rechnungsnummer›
  recipient: (name: "Muster AG"), // no address
  zugferd: "basic", // withheld while data is missing
  validation: "draft", // "strict" stops the build; none checks nothing
)
#body()
