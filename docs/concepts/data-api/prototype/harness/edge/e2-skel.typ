// Skeleton of the e2 invoice (inclusive prices, small business, Austria,
// dated prepayment): hydrated by --input invoice-pro-data-file=e2.json.
#import "/repo/src/lib.typ": *
#import "e2-common.typ": *
#show: invoice.with(
  data: data.load(read: p => read(p, encoding: none)),
  locale: locale.de-at,
  sender: sender2,
  recipient: (name: "S"),
)
#line-items[#item("Sample", price: 1)]
