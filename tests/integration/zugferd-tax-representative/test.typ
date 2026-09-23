// A seller from outside the EU with a fiscal representative (BG-11), in an
// EN 16931 invoice (validated by validate-all-zugferd): a Swiss company
// supplies goods from a warehouse in Germany to a French business, exempt as
// an intra-community supply (K). Its fiscal representative in Germany
// (§ 22a UStG) holds the VAT registration, so the invoice states the
// representative's VAT identifier (BT-63), which satisfies BR-IC-02 without
// being given as the seller's own (BT-31). The seller is identified by its
// Swiss UID (BT-30). The built-in themes do not print the representative,
// so the invoice states it in its text, from the same value.

#import "/src/lib.typ": *

#let representative = (
  name: "Fiskalvertretung Muster GmbH",
  address: "Steuerweg 3",
  city: "60311 Frankfurt am Main",
  country: country.de,
  vat-id: "DE987654328",
)

#show: invoice.with(
  theme: themes.blank,
  locale: locale.en-de,
  zugferd: "en16931",
  sender: (
    name: "Alpen Maschinen AG",
    address: "Bahnhofstrasse 1",
    city: "8001 Zürich",
    country: country.ch,
    legal-id: id.uid-ch("CHE-123.456.788"),
    tax-representative: representative,
    contact: (
      name: "Anna Keller",
      phone: "+41 44 1234567",
      email: "billing@alpen-maschinen.example",
    ),
  ),
  recipient: (
    name: "Client SAS",
    address: "10 Avenue Foch",
    city: "69001 Lyon",
    country: country.fr,
    vat-id: "FR61954506077",
  ),
  invoice-nr: "AM-2026-017",
  date: datetime(year: 2026, month: 9, day: 1),
)

Fiscal representative: #representative.name, #representative.address,
#representative.city, VAT ID #representative.vat-id.

#line-items[
  #item(
    [Machine tool, shipped from Frankfurt am Main to Lyon],
    quantity: 1,
    unit: unit.piece,
    price: 24500,
    tax: tax.intra-community(),
  )
]
#payment-goal(days: 30)
#bank-details(
  bank: "Beispielbank",
  iban: "CH9300762011623852957",
  bic: "UBSWCHZH80A",
)
