#import "/" + sys.inputs.at("lib", default: "repo") + "/src/lib.typ": *
#import "e2-common.typ": *
#show: invoice.with(
  locale: locale.de-at,
  tax-exempt-small-biz: true,
  tax-mode: "inclusive",
  invoice-nr: "E-2",
  date: datetime(year: 2026, month: 3, day: 2),
  sender: sender2,
  recipient: (
    name: "Privat",
    address: "Gasse 2",
    city: "1010 Wien",
    country: "AT",
  ),
)
#line-items[
  #item("Kurs", quantity: "2", unit: unit.hour, price: "59.90")
  #item("Material", price: "12.00", modifier: discount("Treue", amount: 10%))
  #surcharge("Versand", amount: "4.90")
  #prepayment("20.00", name: "Anzahlung", date: datetime(
    year: 2026,
    month: 2,
    day: 1,
  ))
]
