// Spanish small business franchise (VAT category E) in the BASIC profile,
// with a seller that states its VAT identifier and tax number (BR-E-02).
// Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.es-es,
  zugferd: "basic",
  tax-exempt-small-biz: true,
  sender: (
    name: "Ana García Diseño",
    address: "Calle Mayor 1",
    city: (name: "Madrid", post-code: "28013"),
    country: country.es,
    tax-nr: "12345678Z",
    vat-id: "ES12345678Z",
    contact: (
      name: "Ana García",
      phone: "+34 91 1234567",
      email: "facturas@garcia-diseno.es",
    ),
  ),
  recipient: (
    name: "Cliente SL",
    address: "Calle Sierpes 5",
    city: (name: "Sevilla", post-code: "41004"),
    country: country.es,
    vat-id: "ESB12345674",
  ),
  invoice-nr: "KU-2026-020",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Diseño web], price: 60.00, quantity: 10, unit: unit.hour)
  #item([Mantenimiento], price: 25.00, quantity: 3, unit: unit.month)
]

#payment-goal(days: 30)

#bank-details(
  bank: "Banco Ejemplo",
  iban: "ES9121000418450200051332",
  bic: "CAIXESBBXXX",
)
