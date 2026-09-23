// Gallery: `soft` for a café & bakery with catering (German locale, B2C, gross
// prices, two VAT rates, a regular-customer discount and a deposit).
//   layout: <name>   another layout (default: the look's own, a4-digital)
//   extra: <n>       n extra lines (multi-page test)
//   checks: true     theme.custom.checks(min-contrast: 4.5)
#import "/src/lib.typ": *

#let gallery(
  layout: auto,
  extra: 0,
  checks: false,
  zugferd: none,
  validation: "draft",
  marker: none,
) = invoice(
  theme: theme.soft.with(
    theme.custom.logo(
      image: image("lindenblatt-logo.svg", alt: "Backstube Lindenblatt"),
      height: 13mm,
    ),
    if checks { theme.custom.checks(min-contrast: 4.5) },
    layout: if layout == auto { auto } else {
      dictionary(theme.layout).at(layout)
    },
  ),
  locale: locale.de-de,
  validation: validation,
  sender: (
    name: "Backstube Lindenblatt",
    address: "Lindenstraße 8",
    city: "79098 Freiburg im Breisgau",
    vat-id: "DE287654321",
    tax-nr: "06/123/45678",
    management: [Inhaberin: Marie Lindner],
    extra: (
      Telefon: "0761 555 38 20",
      "E-Mail": "hallo@lindenblatt.de",
      Web: "lindenblatt.de",
    ),
  ),
  recipient: (
    name: "Katharina Sommer",
    address: "Wiesenweg 14",
    city: "79100 Freiburg im Breisgau",
  ),
  date: datetime(year: 2026, month: 9, day: 14),
  invoice-nr: "2026-0381",
  subject: "Catering Geburtstagsbrunch am 12.09.2026",
  tax-mode: "inclusive",
  zugferd: zugferd,
  [
    #marker
    Liebe Frau Sommer, schön, dass wir Ihren Geburtstag mitfeiern durften! Wir berechnen Ihnen:

    #line-items[
      #item(
        [Brunch-Buffet „Sonntagsglück“],
        description: [Brötchen aus unserer Backstube, Aufschnitt, Käse, Rührei, Obstsalat],
        price: 18.5,
        quantity: 24,
        unit: "Pers.",
        tax: 7%,
      )
      #item(
        [Himbeer-Schmand-Torte (16 Stück)],
        price: 42,
        quantity: 2,
        unit: "Stk.",
        tax: 7%,
      )
      #item(
        [Kaffee- und Teebar],
        price: 3.9,
        quantity: 24,
        unit: "Pers.",
        tax: 19%,
      )
      #item(
        [Frisch gepresster Orangensaft],
        price: 7.8,
        quantity: 6,
        unit: "Liter",
        tax: 19%,
      )
      #item(
        [Geschirr- und Besteckverleih],
        price: 35,
        quantity: 1,
        unit: "pauschal",
        tax: 19%,
      )
      #item(
        [Lieferung und Aufbau],
        description: [Freiburg, bis 15 km],
        price: 25,
        quantity: 1,
        unit: "pauschal",
        tax: 19%,
      )
      #for i in range(extra) {
        item(
          [Zusatzgebäck Sorte #(i + 1)],
          price: 1.8,
          quantity: 12,
          unit: "Stk.",
          tax: 7%,
        )
      }
      #discount([Stammkundenrabatt], amount: 5%)
      #prepayment(150, label: "Anzahlung", date: "28.08.2026")
    ]

    #payment-terms(days: 14)
    #bank-details(
      bank: "Sparkasse Freiburg-Nördlicher Breisgau",
      iban: "DE89370400440532013000",
      bic: "COBADEFFXXX",
    )
    // the one-page gallery omits the signature
    #if extra > 0 { signature(name: "Marie Lindner") }
  ],
)
