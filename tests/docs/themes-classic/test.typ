// Source: docs/docs/themes/classic.md — "Quick Start"
#import "/src/lib.typ": *

#show: invoice.with(
  theme: theme.classic, // the default: leaving `theme` out gives the same result
  locale: locale.en-de,
  sender: (
    name: "Hartmann Engineering GmbH",
    address: "Leopoldstraße 88",
    city: "80802 Munich",
    vat-id: "DE271234567",
    register: [Local court Munich, HRB 229104],
    management: [Managing director: Sven Hartmann],
    extra: (Phone: "+49 89 2554 1180", Email: "office@hartmann-eng.de"),
  ),
  recipient: (
    name: "Isartal Housing GmbH",
    address: "Wolfratshauser Str. 190",
    city: "81479 Munich",
  ),
  invoice-nr: "2026-117",
)

#line-items[
  #item([Structural design, work stage 3], price: 8400)
  #item([Permit planning, work stage 4], price: 5250)
  #item([Site visits], quantity: 6, unit: unit.hour, price: 145)
]

#payment-terms(days: 30)
#bank-details(
  bank: "Stadtsparkasse München",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature(name: "Sven Hartmann")
