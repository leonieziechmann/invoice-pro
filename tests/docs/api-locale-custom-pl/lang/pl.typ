// lang/pl.typ
#import "/src/lib.typ": locale

// Define the language overrides for Polish
#let pl = (
  meta: (
    lang: "pl",
  ),
  document: (
    invoice: "Faktura",
  ),
  line-items: (
    position: "Lp.",
    description: "Opis",
    quantity: "Ilość",
    unit-price: "Cena jedn.",
    total: "Razem",
    vat: "VAT",
  ),
  summary: (
    sum: "Suma",
    vat-tax: "Podatek VAT",
    total: "Do zapłaty",
  ),
)
