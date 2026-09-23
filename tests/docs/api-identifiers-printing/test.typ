// Documentation: api-reference/invoice/identifiers.md, "Printing
// Identifiers". The register number is given once: as the legal registration
// identifier of the e-invoice (BT-30) and printed next to the sender address.

#import "/src/lib.typ": *

#let register = id.register("HRB 98765", court: "Amtsgericht München")

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  zugferd: "en16931",
  sender: (
    name: "Tech Solutions GmbH",
    address: "Software Allee 10",
    city: "80331 München",
    country: country.de,
    vat-id: "DE123456788",
    legal-id: register,
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 123456",
      email: "rechnung@techsol.example",
    ),
    // Printed by the DIN 5008 theme next to the sender address
    extra: (("Handelsregister", register.id),),
  ),
  recipient: (
    name: "Kunde GmbH",
    address: "Domstraße 5",
    city: "50667 Köln",
    country: country.de,
    vat-id: "DE987654321",
    legal-id: id.register("HRB 12345", court: "Amtsgericht Köln"),
  ),
  invoice-nr: "RE-2026-0101",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Consulting], quantity: 8, unit: unit.hour, price: 120)
]
#payment-goal(days: 14)
#bank-details(iban: "DE89370400440532013000", bic: "COBADEFFXXX")
