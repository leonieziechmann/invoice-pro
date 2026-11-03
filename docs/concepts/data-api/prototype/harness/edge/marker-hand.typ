// Static rows next to the rows of the data, written by hand: the twin of
// edge-skel.typ with --input marker=1 (and of its preview with the sample).
// --input rows=sample: the sample row in place of the data rows.
#import "/" + sys.inputs.at("lib", default: "repo") + "/src/lib.typ": *
#import "common.typ": *
#show: invoice.with(
  zugferd: zugf,
  sender: sender,
  recipient: if sys.inputs.at("rows", default: "data") == "sample" {
    (name: "Sample")
  } else { rcpt },
  invoice-nr: if sys.inputs.at("rows", default: "data") == "sample" {
    "S"
  } else {
    "E-1"
  },
  date: if sys.inputs.at("rows", default: "data") == "sample" {
    datetime.today()
  } else { datetime(year: 2026, month: 3, day: 2) },
  tax: tax.vat(19%),
)
#line-items(tax: 19%)[
  #item("Statisch vorher", price: 3)
  #if sys.inputs.at("rows", default: "data") == "sample" [
    #item("Sample", price: 1)
  ] else [
    #item("Total statt Preis", quantity: "3", total: "100.00")
    #item(
      "Basismenge",
      quantity: "250",
      base-quantity: "100",
      unit: unit.kg,
      price: "4.20",
      item-id: (standard: "4012345678901", buyer: "K-7"),
    )
    #item("Ohne Einheit", price: "1.00")
    #item("Brutto-Eingabe", price: "119.00", input-gross: true)
    #bundle("Außen", quantity: "2", item-id: "B-1", reference: "PO-9")[
      #item("Innen A", price: "10.00", date: datetime(
        year: 2026,
        month: 2,
        day: 1,
      ))
      #bundle("Innen-Bundle", quantity: "3")[
        #item("Kern", price: "2.00", date: datetime(
          year: 2026,
          month: 2,
          day: 10,
        ))
        #surcharge("Verpackung", amount: "1.00")
      ]
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
  #item("Statisch nachher", price: 4)
]
#payment-terms(days: 14)
