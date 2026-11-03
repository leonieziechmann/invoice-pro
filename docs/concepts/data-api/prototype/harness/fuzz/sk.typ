// The fault-corpus skeleton (engine judge's sk-D.typ): one sample row, data
// as a dictionary from --input f=<corpus file>; payment terms so that a clean
// document is a valid e-invoice with --input zf=auto.
#import "/repo/src/lib.typ": *
#import "common.typ": *
#show: invoice.with(
  data: json(sys.inputs.f),
  zugferd: zugf,
  sender: sender,
  recipient: (name: "Sample"),
  invoice-nr: "S",
  tax: tax.vat(19%),
)
#line-items(tax: 19%)[#item("Sample", price: 1)]
#payment(terms: (days: 14))
