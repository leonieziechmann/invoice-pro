// expect: AGREE_INVALID BR-AG-05
// finding: tax-ipsi-zero-rate-false-negative
//
// IPSI (category M, Ceuta and Melilla) needs a rate above 0 % (BR-AG-05),
// like IGIC (L, BR-AF-05). invoice-pro wrote the 0 % line without a report.

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
    vat-id: "ESA87654321",
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
