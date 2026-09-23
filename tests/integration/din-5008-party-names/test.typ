// The DIN-5008 theme with a sender name in several lines and styled names and
// subject. The PDF metadata, the account holder and the EPC-QR code take the
// plain text of the names, as the e-invoice does (BT-27); the theme used to
// fail with "expected string or array, found content".

#import "/src/lib.typ": *
#import "/src/themes/base-theme/bank-details.typ": render-bank-details
#import "/tests/integration/payment-reference/harness.typ": find-all

#show: invoice.with(
  theme: themes
    .DIN-5008(font: "libertinus serif")
    .with(
      bank-details: (ctx, view) => {
        let printed = render-bank-details(ctx, view)
        [#metadata(printed)<bank-details>#printed]
      },
    ),
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: ("Muster GmbH", [Abteilung _Vertrieb_]),
    address: "Hauptstraße 1",
    city: "10115 Berlin",
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
    contact: (
      name: "Max Muster",
      phone: "+49 30 123456",
      email: "max@muster.de",
    ),
  ),
  recipient: (
    name: [Client #strong[SARL] \ Dépt. 3],
    address: "12 Rue de la Paix",
    city: "75002 Paris",
    country: country.fr,
    vat-id: "FR40303265045",
  ),
  invoice-nr: "RE-2026-001",
  date: datetime(year: 2026, month: 7, day: 1),
  subject: [Rechnung für *Beratung*],
)

#line-items[
  #item(
    [Beratung],
    quantity: 10,
    price: 100,
    unit: unit.hour,
    tax: tax.vat(19%),
  )
]

#payment-goal(days: 14)
#bank-details(bank: "Musterbank", iban: "DE89370400440532013000")

#context {
  let seller = "Muster GmbH, Abteilung Vertrieb"

  // PDF metadata
  assert.eq(document.author, (seller,))
  assert.eq(document.description, [#"Rechnung für Beratung RE-2026-001"])

  // EPC-QR code
  let printed = query(<bank-details>).map(it => it.value)
  assert.eq(printed.len(), 1, message: "printed bank details")
  let epc = find-all(printed.first(), image).first().alt.split("\n")
  assert.eq(epc.at(5), seller, message: "EPC beneficiary")

  // E-invoice (BT-27)
  let xml = str(query(pdf.attach).first().data)
  assert(
    xml.contains("<ram:Name>" + seller + "</ram:Name>"),
    message: "Seller name in the XML",
  )
}
