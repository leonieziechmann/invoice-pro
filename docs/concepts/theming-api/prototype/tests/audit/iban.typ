// An invalid IBAN is a data issue (class data): draft renders it with a report row
// and withholds the XML, strict panics, none renders; never a renderer panic.
//   --input look=<preset>  --input zugferd=1
#import "/tests/body.typ": *
#show: invoice.with(
  theme: dictionary(theme).at(sys.inputs.at("look", default: "classic")),
  locale: test-locale,
  ..party,
  zugferd: if sys.inputs.at("zugferd", default: none) != none { "basic" },
)
#line-items[#item([X], price: 10)]
#bank-details(
  iban: "DE00 1234 5678 9012 3456 78",
  bic: "COBADEFFXXX",
  bank: "Bank",
)
