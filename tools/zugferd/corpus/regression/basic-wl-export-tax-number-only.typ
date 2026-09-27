// expect: AGREE_VALID
// finding: core-basicwl-category-id-rules
//
// A German exporter with only a tax number (no VAT identifier) may write a
// BASIC WL invoice: the profile has no BR-G-02. invoice-pro blocked it.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de + (vat-id: none),
  recipient: (
    name: "Kunde AG",
    address: "Bahnhofstrasse 1",
    city: (name: "Zürich", post-code: "8001"),
    country: country.ch,
  ),
  invoice-nr: "RG-BWL-EXPORT",
)

#line-items[
  #item(
    [Maschine],
    price: 1000,
    quantity: 1,
    tax: tax.export(grounds: "Steuerfreie Ausfuhrlieferung"),
  )
]
#payment-goal(days: 14)
#bank
