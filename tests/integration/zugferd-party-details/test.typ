// The party details of EN 16931 besides names, addresses and VAT
// identifiers, in an XRechnung to a public buyer (validated by
// validate-all-zugferd):
//
// - the seller's legal registration identifier (BT-30: a register number with
//   its court, printed from the same value in `extra`), trading name (BT-28)
//   and additional legal information (BT-33);
// - the buyer's Leitweg-ID of the `id` module as buyer reference (BT-10) and
//   electronic address (BT-49, scheme 0204), and its contact (BG-9);
// - a factoring company as payee (BG-10), with its GLN (BT-60) and register
//   number (BT-61).

#import "/src/lib.typ": *

#let register = id.register("HRB 98765", court: "Amtsgericht München")
#let leitweg = id.leitweg("04011000-1234512345-06")

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "xrechnung",
  sender: (
    name: "Tech Solutions GmbH",
    trading-name: "TechSol",
    address: "Software Allee 10",
    city: "80331 München",
    country: country.de,
    tax-nr: "143/123/45678",
    vat-id: "DE123456788",
    legal-id: register,
    legal-info: "Geschäftsführer: Max Mustermann, Sitz der Gesellschaft: München",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 123456",
      email: "rechnung@techsol.example",
    ),
    extra: (("Handelsregister", register.id),),
  ),
  recipient: (
    name: "Stadt Musterstadt",
    address: "Rathausplatz 1",
    city: "12345 Musterstadt",
    country: country.de,
    leitweg-id: leitweg,
    electronic-address: leitweg,
    contact: (
      name: "Frau Beispiel",
      phone: "+49 123 4567",
      email: "beschaffung@musterstadt.example",
    ),
  ),
  payee: (
    name: "Factoring Bank AG",
    global-id: id.gln("4000001543212"),
    legal-id: id.register("HRB 12345", court: "Amtsgericht Frankfurt am Main"),
  ),
  invoice-nr: "RE-2026-0100",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Wartungsvertrag Q3], quantity: 1, unit: unit.piece, price: 1200.00)
]
#payment-goal(days: 30)
#bank-details(
  name: "Factoring Bank AG",
  bank: "Factoring Bank AG",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
