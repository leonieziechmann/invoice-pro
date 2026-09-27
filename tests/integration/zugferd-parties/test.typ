// Party data as it often comes from imported data or copied text, written as
// a valid XRechnung (validated by validate-all-zugferd):
//
// - the seller's `electronic-address` is empty, so it is derived from the VAT
//   ID, which contains a zero width space;
// - the invoice is not subject to VAT (category O): the VAT identifiers are
//   left out (BR-O-02), but the buyer is still reached by the electronic
//   address derived from its VAT ID (PEPPOL-EN16931-R010);
// - the buyer name has two lines (BT-44);
// - the delivery address is identified by a GLN given as `id` (BT-71).

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "xrechnung",
  tax: tax.outside-scope(grounds: "Nicht steuerbarer Schadensersatz."),
  sender: (
    name: "Muster Logistik GmbH",
    address: "Hauptstraße 1",
    city: "10115 Berlin",
    country: country.de,
    tax-nr: "143/123/45678",
    vat-id: "DE\u{200B}123456789",
    electronic-address: "",
    contact: (
      name: "Max Muster",
      phone: "+49 30 123456",
      email: "max@muster-logistik.de",
    ),
  ),
  recipient: (
    name: ("Kunde GmbH", "Buchhaltung"),
    address: "Kundenweg 5",
    city: "80331 München",
    country: country.de,
    vat-id: "DE987654321",
    buyer-reference: "04011000-12345-67",
  ),
  delivery-address: (
    name: "Kunde GmbH Lager",
    address: "Lagerstraße 9",
    city: "85748 Garching",
    id: (scheme: "0088", id: "4000001123452"),
  ),
  invoice-nr: "RE-2026-042",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Schadensersatz für beschädigte Ware], price: 450)
]
#payment-goal(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
