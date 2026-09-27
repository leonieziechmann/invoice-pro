// expect: AGREE_VALID
// finding: parties-bg11-tax-representative-missing
// facts: {"seller_legal_id": ["0183", "CHE123456788"], "tax_representative": {"name": "Fiskalvertretung Muster GmbH", "vat": "DE987654328", "country": "DE"}, "breakdown": [["K", "0"]]}
//
// A Swiss seller whose fiscal representative in Germany holds its VAT
// registration (§ 22a UStG) supplies goods to France (K). The rules accept
// the representative's VAT identifier (BT-63, BR-IC-02); without the tax
// representative (BG-11), the only way was to give it as the seller's own
// VAT identifier (BT-31), which is false.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  locale: locale.en-de,
  zugferd: "en16931",
  sender: (
    name: "Alpen Maschinen AG",
    address: "Bahnhofstrasse 1",
    city: (name: "Zürich", post-code: "8001"),
    country: country.ch,
    legal-id: id.uid-ch("CHE-123.456.788"),
    contact: contact,
    tax-representative: (
      name: "Fiskalvertretung Muster GmbH",
      address: "Steuerweg 3",
      city: (name: "Frankfurt am Main", post-code: "60311"),
      country: country.de,
      vat-id: "DE987654328",
    ),
  ),
  recipient: buyer-fr,
  invoice-nr: "RG-TAX-REP",
)

#line-items[
  #item(
    [Werkzeugmaschine],
    price: 24500,
    quantity: 1,
    tax: tax.intra-community(),
  )
]
#payment-goal(days: 30)
#bank
