// Every date an invoice takes names a day. A `datetime` of a time only, e.g.
// `datetime(hour: 1, minute: 0, second: 0)`, can be neither printed as a date
// nor written into the e-invoice: it stops the compilation with a message
// that names the input, instead of failing somewhere in the date format of
// the locale ("failed to format datetime").

#import "/src/lib.typ": *

#let time-only = datetime(hour: 1, minute: 0, second: 0)
#let day = datetime(year: 2026, month: 9, day: 1)

#let seller = (
  name: "Seller GmbH",
  address: "Street 1",
  city: (name: "München", post-code: "80339"),
  country: country.de,
  vat-id: "DE123456789",
)
#let buyer = (
  name: "Buyer GmbH",
  address: "Weg 5",
  city: (name: "Berlin", post-code: "10115"),
  country: country.de,
)

// The message an invoice stops with, or `none`.
#let message(zugferd: none, body: none, ..args) = catch(() => invoice(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale.de-de,
  sender: seller,
  recipient: buyer,
  invoice-nr: "2026-01",
  date: day,
  zugferd: zugferd,
  ..args,
)[
  #line-items[
    #item([Consulting], price: 100, quantity: 1, tax: tax.vat(19%))
    #body
  ]
  #payment-goal(days: 14)
  #bank-details(bank: "Musterbank", iban: "DE89370400440532013000")
])

// The message names the input and says that its day is missing.
#let stops(got, field) = {
  let expected = "`" + field + "` is a time without a day"
  assert(
    got != none and got.contains(expected),
    message: "Expected `" + expected + "`, got " + repr(got),
  )
}

// The inputs of the invoice.
#stops(message(date: time-only), "invoice::date")
#stops(message(date: time-only, zugferd: "en16931"), "invoice::date")
#stops(message(service-period: time-only), "invoice::service-period")
#stops(message(service-period: (day, time-only)), "invoice::service-period")
#stops(message(order-date: time-only), "invoice::order-date")
#stops(
  message(recipient: buyer + (order-date: time-only)),
  "recipient.order-date",
)
#stops(
  message(preceding-invoice-nr: "2026-00", preceding-invoice-date: time-only),
  "invoice::preceding-invoice-date",
)
#stops(message(due-date: time-only), "invoice::due-date")

// The dates of the items and of the other components, which stop when they
// are called.
#stops(
  catch(() => item([Support], price: 50, date: time-only)),
  "item::date",
)
#stops(
  catch(() => item([Support], price: 50, date: (day, time-only))),
  "item::date",
)
#stops(
  catch(() => bundle([Set], date: time-only)[#item([Part], price: 10)]),
  "bundle::date",
)
#stops(
  catch(() => group([Phase 1], date: time-only)[#item([Part], price: 10)]),
  "group::date",
)
#stops(
  catch(() => prepayment(10, date: time-only)),
  "prepayment::date",
)
#stops(catch(() => payment-goal(date: time-only)), "payment-goal::date")
#stops(catch(() => paid(method: "cash", date: time-only)), "paid::date")

// A dated item compiles.
#assert.eq(message(body: item([Support], price: 50, date: day)), none)

// The values of the reference signs.
#stops(
  catch(() => references.invoice-date(value: time-only)),
  "references.invoice-date::value",
)
#stops(
  catch(() => references.service-time(value: time-only)),
  "references.service-time::value",
)
#stops(
  catch(() => references.service-time(value: (day, time-only))),
  "references.service-time::value",
)
#stops(
  catch(() => references.order-date(value: time-only)),
  "references.order-date::value",
)
#stops(
  catch(() => references.preceding-invoice-date(value: time-only)),
  "references.preceding-invoice-date::value",
)
#stops(
  catch(() => references.due-date(value: time-only)),
  "references.due-date::value",
)

// A date with a time of day names its day, and so does a period of them.
#assert.eq(
  message(
    date: datetime(
      year: 2026,
      month: 9,
      day: 1,
      hour: 9,
      minute: 30,
      second: 0,
    ),
    service-period: (day, datetime(year: 2026, month: 9, day: 30)),
  ),
  none,
)
