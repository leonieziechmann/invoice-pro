// expect: AGREE_VALID
// finding: tax-ipsi-zero-rate-false-negative
//
// IPSI (category M, Ceuta and Melilla) at 0 %: the CEN Schematron 1.3.16 and
// Factur-X 1.09 accept it (BR-AG-05, "0 (zero) or greater than zero"); CEN
// 1.3.12 of Mustang 2.14.0 required a rate above 0, and invoice-pro reported
// BR-AG-05. A negative rate is an error (corpus/rules/BR-AG-05.typ).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  locale: locale.es-es,
  zugferd: "en16931",
  sender: (
    name: "Vendedor SL",
    address: "Calle Real 1",
    city: (name: "Ceuta", post-code: "51001"),
    country: country.es,
    vat-id: "ESB12345674",
    contact: (
      name: "Ana",
      phone: "+34 956 123456",
      email: "ana@vendedor.example",
    ),
  ),
  recipient: (
    name: "Comprador SA",
    address: "Calle Mayor 2",
    city: (name: "Madrid", post-code: "28001"),
    country: country.es,
    vat-id: "ESA87654323",
    email: "facturas@comprador.example",
  ),
  invoice-nr: "RG-IPSI-0",
)

#line-items[
  #item(
    [Servicio],
    price: 100.00,
    quantity: 1,
    tax: tax.special.ceuta-melilla(0%),
  )
]
#payment-goal(days: 14)
#bank
