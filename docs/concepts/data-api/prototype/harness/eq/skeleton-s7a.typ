// The skeleton of the generated equivalence/benchmark invoices: designed by
// hand with SAMPLE data, the whole `line-items` body as the implicit slot (no
// marker); `--input invoice-pro-data-file=data/<k>-<n>.json` hydrates it.
#import "/repo-s7a/src/lib.typ": *
#let zf = sys.inputs.at("zf", default: "none")
#show: invoice.with(
  data: invoice-data.load(read: p => read(p, encoding: none)),
  theme: theme.classic,
  zugferd: if zf == "none" { none } else if zf == "auto" { auto } else { zf },
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: "DE",
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@consultinggroup.de",
    ),
  ),
  // samples, replaced by the data
  recipient: (
    name: "Musterkunde GmbH",
    address: "Musterweg 1",
    city: "10115 Berlin",
    country: "DE",
  ),
  invoice-nr: "MUSTER-0001",
  date: datetime(year: 2026, month: 1, day: 15),
  tax: tax.vat(19%),
)
#line-items[
  #item("Beratung (Muster)", quantity: 2, unit: unit.hour, price: 120)
  #item("Reisekosten (Muster)", price: 80)
]
#payment(
  terms: (days: 14),
  bank: (
    bank: "Global Business Bank",
    iban: "DE89370400440532013000",
    bic: "GBBADEFFXXX",
  ),
)
