#import "/" + sys.inputs.at("lib", default: "repo") + "/src/lib.typ": *
// (prototype: `#payment-terms(days: 14)` appended so the e-invoice is valid with zf=auto)
#import "common.typ": *
#let nul = sys.inputs.at("nul", default: "1") == "1"
#let flat = sys.inputs.at("flat", default: "0") == "1"
#let wrap = sys.inputs.at("wrap", default: "0") == "1"
#show: invoice.with(
  zugferd: zugf,
  sender: sender,
  recipient: rcpt,
  invoice-nr: "E-1",
  date: datetime(year: 2026, month: 3, day: 2),
  tax: tax.vat(19%),
)
#let rows = [
  #item("Total statt Preis", quantity: "3", total: "100.00")
  #item(
    "Basismenge",
    quantity: "250",
    base-quantity: "100",
    unit: unit.kg,
    price: "4.20",
    item-id: (standard: "4012345678901", buyer: "K-7"),
  )
  #if nul {
    item("Ohne Einheit", unit: none, price: "1.00", description: none)
  } else { item("Ohne Einheit", price: "1.00") }
  #item("Brutto-Eingabe", price: "119.00", input-gross: true)
  #bundle("Außen", quantity: "2", item-id: "B-1", reference: "PO-9")[
    #item("Innen A", price: "10.00", date: datetime(
      year: 2026,
      month: 2,
      day: 1,
    ))
    #if flat [#item("Kern", price: "2.00", date: datetime(
      year: 2026,
      month: 2,
      day: 10,
    ))] else [#bundle("Innen-Bundle", quantity: "3")[
      #item("Kern", price: "2.00", date: datetime(
        year: 2026,
        month: 2,
        day: 10,
      ))
      #surcharge("Verpackung", amount: "1.00")
    ]]
    #discount("Korrektur", amount: "0.50")
  ]
  #group("Gruppe ohne Summe", show-subtotal: false, date: (
    datetime(year: 2026, month: 2, day: 1),
    datetime(year: 2026, month: 2, day: 28),
  ))[
    #item("In Gruppe", price: "5.55", tax: 7%)
    #group("Untergruppe", unit: unit.day)[#item(
      "Tief",
      quantity: "2",
      price: "8.00",
    )]
  ]
  #discount("Fix", amount: "5.00", tax: 19%)
  #prepayment(25%, name: "Vorkasse", method: "Überweisung", reference: "VK-1")
]
#line-items(tax: 19%)[
  #if wrap [#item("Statisch vorher", price: 3)
    #apply(description: "Kaskade")[#rows]
    #item("Statisch nachher", price: 4)] else { rows }
]
#payment-terms(days: 14)
